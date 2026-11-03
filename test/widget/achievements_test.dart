import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:redemption/core/time/day.dart';
import 'package:redemption/data/repositories/entry_repository.dart';
import 'package:redemption/data/repositories/journey_repository.dart';
import 'package:redemption/data/repositories/tracker_repository.dart';
import 'package:redemption/domain/models.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/domain/tracker_value.dart';

import '../support/harness.dart';

void main() {
  // Monday 5 October: every prayer in congregation, and trained.
  const monday = Day(2026, 10, 5);

  Future<List<Tracker>> seed(TestEnv env) async {
    final journey = (await JourneyRepository(env.db).active())!;
    final trackers = await TrackerRepository(env.db).forJourney(journey.id);
    final entries = EntryRepository(env.db);
    for (final name in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      await entries.upsert(
        trackerId: trackers.firstWhere((t) => t.name == name).id,
        day: monday,
        value: const ChoiceValue('jamaah'),
      );
    }
    await entries.upsert(
      trackerId: trackers.firstWhere((t) => t.name == 'Workout').id,
      day: monday,
      value: const BoolValue(true),
    );
    return trackers;
  }

  Future<void> openJourneyGrid(WidgetTester tester) async {
    await tester.tap(find.text('Insights').last);
    await settle(tester);
    await tester.dragUntilVisible(
      find.text('Every day of the journey'),
      find.byType(Scrollable).first,
      const Offset(0, -250),
    );
    await settle(tester);
  }

  testWidgets('the journey grid shows each day\'s achievements as tiny '
      'emojis, with a legend and the details in the day sheet', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    await tester.runAsync(() => seed(env));

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await openJourneyGrid(tester);

    final cell = find.text('🕌💪');
    await tester.ensureVisible(cell);
    await settle(tester);
    expect(cell, findsOneWidget);
    expect(find.text('🕌 Every prayer in congregation'), findsOneWidget);
    expect(find.text('💪 Workout'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(cell);
    await settle(tester);
    expect(
      find.widgetWithText(Chip, 'All 5 prayers in congregation'),
      findsOneWidget,
    );
    expect(find.widgetWithText(Chip, 'Workout'), findsOneWidget);
  });

  testWidgets('large text keeps the tiles intact', (tester) async {
    usePhoneSurface(tester, textScale: 2);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    await tester.runAsync(() => seed(env));

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await openJourneyGrid(tester);
    await tester.ensureVisible(find.text('🕌💪'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tracker\'s emoji can be changed or turned off', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    final trackers = (await tester.runAsync(() => seed(env)))!;
    final workoutId = trackers.firstWhere((t) => t.name == 'Workout').id;

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await tester.tap(find.text('Plan').last);
    await settle(tester);
    await tester.dragUntilVisible(
      find.text('Workout'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
    await settle(tester);
    await tester.tap(find.text('Workout'));
    await settle(tester);
    final field = find.widgetWithText(
      TextFormField,
      'Achievement emoji (optional)',
    );
    await tester.dragUntilVisible(
      field,
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await settle(tester);
    expect(
      tester.widget<TextFormField>(field).controller!.text,
      '💪',
      reason: 'the default for "Workout"',
    );
    await tester.ensureVisible(find.text('None'));
    await settle(tester);
    await tester.tap(find.text('None'));
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    final saved = (await tester.runAsync(
      () => TrackerRepository(env.db).forJourney(1),
    ))!.firstWhere((t) => t.id == workoutId);
    expect(saved.config.badge, '');

    await tester.tap(find.text('Insights').last);
    await settle(tester);
    await openJourneyGrid(tester);
    expect(find.text('🕌'), findsOneWidget);
    expect(find.text('💪 Workout'), findsNothing);
  });

  testWidgets('the legend only explains emojis the tiles draw', (tester) async {
    usePhoneSurface(tester); // 393dp: two emojis per tile
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    await tester.runAsync(() async {
      final trackers = await seed(env);
      await EntryRepository(env.db).upsert(
        trackerId: trackers.firstWhere((t) => t.name == 'Wake-up time').id,
        day: monday,
        value: const TimeValue(4 * 60 + 30),
      );
    });

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await openJourneyGrid(tester);
    await tester.ensureVisible(find.text('🕌🌅'));
    await settle(tester);
    expect(find.text('🕌🌅'), findsOneWidget);
    expect(find.text('🌅 Wake-up time'), findsOneWidget);
    expect(find.text('💪 Workout'), findsNothing, reason: 'not on any tile');
  });

  Future<Finder> openEditor(WidgetTester tester, String name) async {
    await tester.tap(find.text('Plan').last);
    await settle(tester);
    await tester.dragUntilVisible(
      find.text(name),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
    await settle(tester);
    await tester.tap(find.text(name));
    await settle(tester);
    final field = find.widgetWithText(
      TextFormField,
      'Achievement emoji (optional)',
    );
    await tester.dragUntilVisible(
      field,
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await settle(tester);
    return field;
  }

  testWidgets('typing a new emoji replaces the old one; the grid\'s own '
      'emojis are refused', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    final trackers = (await tester.runAsync(() => seed(env)))!;
    final workoutId = trackers.firstWhere((t) => t.name == 'Workout').id;

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    final field = await openEditor(tester, 'Workout');
    // Typed after the 💪 already there.
    await tester.enterText(field, '💪🎯');
    await settle(tester);
    expect(tester.widget<TextFormField>(field).controller!.text, '🎯');

    await tester.enterText(field, '🔥');
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.textContaining('The grid uses this one'), findsOneWidget);

    await tester.enterText(field, '🎯');
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
    final saved = (await tester.runAsync(
      () => TrackerRepository(env.db).forJourney(1),
    ))!.firstWhere((t) => t.id == workoutId);
    expect(saved.config.badge, '🎯');
  });

  testWidgets('a new tracker named like a template one gets its emoji', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.blank);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await tester.tap(find.text('Plan').last);
    await settle(tester);
    await tester.tap(find.text('New tracker'));
    await settle(tester);
    await tester.tap(find.text('Yes / No'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Workout',
    );
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    final journey = (await tester.runAsync(
      () => JourneyRepository(env.db).active(),
    ))!;
    final saved = (await tester.runAsync(
      () => TrackerRepository(env.db).forJourney(journey.id),
    ))!.single;
    expect(saved.config.badge, '💪');
  });
}
