import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:redemption/data/repositories/entry_repository.dart';
import 'package:redemption/data/repositories/journey_repository.dart';
import 'package:redemption/data/repositories/tracker_repository.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/domain/tracker_value.dart';

import '../support/harness.dart';

void main() {
  testWidgets('first run walks through onboarding into the dashboard', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env));
    await settle(tester);

    expect(find.text('Rewire your brain\nin 90 days.'), findsOneWidget);
    await tester.tap(find.text('Let’s build it'));
    await settle(tester);

    expect(find.text('Start from a template'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await settle(tester);

    expect(find.text('Shape your journey'), findsOneWidget);
    await tester.tap(find.text('Bismillah — begin'));
    await settle(tester, rounds: 10);

    final journey = await tester.runAsync(
      () => JourneyRepository(env.db).active(),
    );
    expect(journey?.name, Templates.redemption.suggestedName);
    expect(find.text('Salah today'), findsOneWidget);
  });

  testWidgets('dashboard shows the journey ring and configured widgets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env));
    await settle(tester);

    expect(find.text('Redemption'), findsOneWidget);
    expect(find.text('90 Days of Redemption'), findsOneWidget);
    expect(find.text('Salah today'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Day 10 of 90')), findsWidgets);
    semantics.dispose();
  });

  testWidgets('one tap on the Today timeline logs a prayer', (tester) async {
    final semantics = tester.ensureSemantics();
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);

    expect(find.text('Day 10 of 90'), findsOneWidget);
    // The Fajr tile offers inline one-tap options while pending.
    await tester.tap(find.bySemanticsLabel('Log In congregation').first);
    await settle(tester);

    final journey = (await tester.runAsync(
      () => JourneyRepository(env.db).active(),
    ))!;
    final entries = (await tester.runAsync(
      () => EntryRepository(env.db).watchForJourney(journey.id).first,
    ))!;
    expect(entries.length, 1);
    expect(entries.single.value, const ChoiceValue('jamaah'));
    semantics.dispose();
  });

  testWidgets('a checkbox tracker can be completed from the timeline', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);

    final markButton = find.byTooltip('Mark Had it');
    await tester.dragUntilVisible(
      markButton,
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await tester.tap(markButton);
    await settle(tester);

    final journey = (await tester.runAsync(
      () => JourneyRepository(env.db).active(),
    ))!;
    final entries = (await tester.runAsync(
      () => EntryRepository(env.db).watchForJourney(journey.id).first,
    ))!;
    expect(entries.single.value, const BoolValue(true));
  });

  testWidgets('a new tracker can be created from the Plan tab', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.blank);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await tester.tap(find.text('Plan').last);
    await settle(tester);
    await tester.tap(find.text('New tracker'));
    await settle(tester);

    await tester.tap(find.text('Counter'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Water');
    await tester.tap(find.text('Save'));
    await settle(tester);

    final journey = (await tester.runAsync(
      () => JourneyRepository(env.db).active(),
    ))!;
    final trackers = (await tester.runAsync(
      () => TrackerRepository(env.db).forJourney(journey.id),
    ))!;
    expect(trackers.single.name, 'Water');
    expect(find.text('Water'), findsOneWidget);
  });

  testWidgets('every tab survives 200% text scaling without overflow', (
    tester,
  ) async {
    usePhoneSurface(tester, textScale: 2);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    for (final tab in ['Today', 'Insights', 'Plan', 'Home']) {
      await tester.tap(find.text(tab).last);
      await settle(tester);
    }
    expect(tester.takeException(), isNull);
  });
}
