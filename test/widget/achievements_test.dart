import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:redemption/core/time/day.dart';
import 'package:redemption/data/repositories/dashboard_repository.dart';
import 'package:redemption/data/repositories/entry_repository.dart';
import 'package:redemption/data/repositories/journey_repository.dart';
import 'package:redemption/data/repositories/settings_repository.dart';
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
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    await tester.runAsync(() async {
      // Two emojis per tile.
      final settings = SettingsRepository(env.db);
      await settings.save(
        (await settings.load()).copyWith(gridEmojisPerTile: 2),
      );
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

  testWidgets('a tile holds up to six emojis in two rows', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    await tester.runAsync(() async {
      final trackers = await seed(env);
      final entries = EntryRepository(env.db);
      int id(String name) => trackers.firstWhere((t) => t.name == name).id;
      await entries.upsert(
        trackerId: id('Wake-up time'),
        day: monday,
        value: const TimeValue(4 * 60 + 30),
      );
      await entries.upsert(
        trackerId: id('Sleep time'),
        day: monday,
        value: const TimeValue(22 * 60),
      );
      for (final meal in ['Breakfast', 'Lunch', 'Dinner']) {
        await entries.upsert(
          trackerId: id('$meal on time?'),
          day: monday,
          value: const BoolValue(true),
        );
      }
    });

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await openJourneyGrid(tester);
    // 🕌 🍽️ 🌅 💪 🌙: three on top, two below.
    final top = find.text('🕌🍽️🌅');
    await tester.ensureVisible(top);
    await settle(tester);
    expect(top, findsOneWidget);
    expect(find.text('💪🌙'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the grid settings choose what the tiles show', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    await tester.runAsync(() => seed(env));

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await openJourneyGrid(tester);
    await tester.tap(find.byTooltip('Choose achievements on the tiles'));
    await settle(tester);
    expect(find.text('Achievements on the tiles'), findsOneWidget);
    final workout = find.widgetWithText(FilterChip, '💪  Workout');
    await tester.ensureVisible(workout);
    await settle(tester);
    expect(tester.widget<FilterChip>(workout).selected, isTrue);
    await tester.tap(workout);
    await settle(tester);
    await tester.ensureVisible(find.text('Done'));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    final settings = (await tester.runAsync(
      () => SettingsRepository(env.db).load(),
    ))!;
    final workoutId = (await tester.runAsync(
      () => TrackerRepository(env.db).forJourney(1),
    ))!.firstWhere((t) => t.name == 'Workout').id;
    expect(settings.gridHiddenAchievements, {'tracker:$workoutId'});
    expect(find.text('🕌'), findsOneWidget, reason: '💪 left off the tile');
    expect(find.text('💪 Workout'), findsNothing);
  });

  testWidgets('the Home grid switches what colours it, right on the card', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    await tester.runAsync(() => seed(env));

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    final pill = find.byTooltip('Colour the grid by');
    await tester.dragUntilVisible(
      pill,
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    await settle(tester);
    expect(find.text('Journey grid'), findsOneWidget);
    await tester.tap(pill);
    await settle(tester);
    await tester.tap(find.text('Workout').last);
    await settle(tester);

    expect(find.text('Workout grid'), findsOneWidget);
    final items = (await tester.runAsync(
      () => DashboardRepository(env.db).watch(1).first,
    ))!;
    final workoutId = (await tester.runAsync(
      () => TrackerRepository(env.db).forJourney(1),
    ))!.firstWhere((t) => t.name == 'Workout').id;
    expect(
      items.firstWhere((i) => i.kind.name == 'heatmap').config.trackerIds,
      [workoutId],
    );

    // And back to the daily score.
    await tester.tap(find.byTooltip('Colour the grid by'));
    await settle(tester);
    await tester.tap(find.text('Daily score (with achievements)'));
    await settle(tester);
    expect(find.text('Journey grid'), findsOneWidget);
  });

  testWidgets('the Journey grid\'s customise sheet holds the tile settings', (
    tester,
  ) async {
    usePhoneSurface(tester, textScale: 1.3);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await tester.tap(find.byTooltip('Customise dashboard'));
    await settle(tester);
    final grid = find.ancestor(
      of: find.text('Journey grid'),
      matching: find.byType(ListTile),
    );
    await tester.dragUntilVisible(
      grid,
      find.byType(Scrollable).first,
      const Offset(0, -250),
    );
    await settle(tester);
    await tester.tap(
      find.descendant(of: grid, matching: find.byTooltip('Configure')),
    );
    await settle(tester);
    final compact = find.widgetWithText(
      SwitchListTile,
      'Perfect days show just 🌟',
    );
    await tester.ensureVisible(compact);
    await settle(tester);
    await tester.tap(compact);
    await settle(tester);
    await tester.tap(find.text('4'));
    await settle(tester);
    await tester.ensureVisible(find.text('Done'));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    final settings = (await tester.runAsync(
      () => SettingsRepository(env.db).load(),
    ))!;
    expect(settings.gridCompactPerfect, isTrue);
    expect(settings.gridEmojisPerTile, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new journey copying the trackers keeps hidden emojis hidden', (
    tester,
  ) async {
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    await tester.runAsync(() async {
      final journey = (await JourneyRepository(env.db).active())!;
      final trackers = await TrackerRepository(env.db).forJourney(journey.id);
      final wake = trackers.firstWhere((t) => t.name == 'Wake-up time');
      final settings = SettingsRepository(env.db);
      await settings.save(
        (await settings.load()).copyWith(
          gridHiddenAchievements: {'streak', 'tracker:${wake.id}'},
        ),
      );
      final copy = await JourneyRepository(env.db).createFromExisting(
        copyFrom: journey.id,
        name: 'Round 2',
        intention: '',
        startDay: const Day(2026, 12, 30),
        durationDays: 90,
      );
      final copied = (await TrackerRepository(env.db).forJourney(copy))
          .firstWhere((t) => t.name == 'Wake-up time');
      expect((await settings.load()).gridHiddenAchievements, {
        'streak',
        'tracker:${wake.id}',
        'tracker:${copied.id}',
      });
    });
  });

  testWidgets('a grid coloured by a deleted tracker offers the tile settings', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    await tester.runAsync(() async {
      final repo = DashboardRepository(env.db);
      final grid = (await repo.watch(1).first).firstWhere(
        (i) => i.kind.name == 'heatmap',
      );
      await repo.update(
        grid.copyWith(config: grid.config.copyWith(trackerIds: [9999])),
      );
    });

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await tester.tap(find.byTooltip('Customise dashboard'));
    await settle(tester);
    final grid = find.ancestor(
      of: find.text('Journey grid'),
      matching: find.byType(ListTile),
    );
    await tester.dragUntilVisible(
      grid,
      find.byType(Scrollable).first,
      const Offset(0, -250),
    );
    await settle(tester);
    await tester.tap(
      find.descendant(of: grid, matching: find.byTooltip('Configure')),
    );
    await settle(tester);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Daily score'))
          .selected,
      isTrue,
    );
    await tester.dragUntilVisible(
      find.text('Achievements on the tiles'),
      find.byType(Scrollable).last,
      const Offset(0, -200),
    );
    expect(find.text('Achievements on the tiles'), findsOneWidget);
  });

  Future<void> scrollToPill(WidgetTester tester) async {
    await tester.dragUntilVisible(
      find.byTooltip('Colour the grid by'),
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    await settle(tester);
  }

  testWidgets('the colour pill is its own button, not the whole card', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await scrollToPill(tester);
    final pill = tester.getSemantics(find.byTooltip('Colour the grid by'));
    expect(pill.label, contains('Colour by'));
    expect(pill.flagsCollection.isButton, isTrue);
    final grid = tester.getSemantics(
      find.bySemanticsLabel(RegExp('winning days so far')).first,
    );
    expect(grid.flagsCollection.isButton, isFalse);
    expect(
      tester.getSize(find.byTooltip('Colour the grid by')).height,
      greaterThanOrEqualTo(48),
    );
    handle.dispose();
  });

  testWidgets('a grid coloured by an archived tracker keeps it on the menu', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    await tester.runAsync(() async {
      final trackers = await TrackerRepository(env.db).forJourney(1);
      final workout = trackers.firstWhere((t) => t.name == 'Workout');
      final repo = DashboardRepository(env.db);
      final grid = (await repo.watch(1).first).firstWhere(
        (i) => i.kind.name == 'heatmap',
      );
      await repo.update(
        grid.copyWith(config: grid.config.copyWith(trackerIds: [workout.id])),
      );
      await TrackerRepository(env.db)
          .archive(workout.id, const Day(2026, 10, 8));
    });

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await scrollToPill(tester);
    await tester.tap(find.byTooltip('Colour the grid by'));
    await settle(tester);
    final archived = find.text('Workout (archived)');
    expect(archived, findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(of: archived, matching: find.byType(Row)).first,
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('on a narrow phone with large text the pill takes its own line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(880, 2400); // 320dp
    tester.view.devicePixelRatio = 2.75;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    await tester.runAsync(() async {
      final repo = TrackerRepository(env.db);
      final workout = (await repo.forJourney(1))
          .firstWhere((t) => t.name == 'Workout');
      await repo.update(
        workout.copyWith(name: 'Did you skip watching filth today?'),
      );
      final dash = DashboardRepository(env.db);
      final grid = (await dash.watch(1).first).firstWhere(
        (i) => i.kind.name == 'heatmap',
      );
      await dash.update(
        grid.copyWith(config: grid.config.copyWith(trackerIds: [workout.id])),
      );
    });

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await scrollToPill(tester);
    expect(
      tester.getTopLeft(find.text('Colour by')).dy,
      lessThan(tester.getTopLeft(find.byTooltip('Colour the grid by')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
