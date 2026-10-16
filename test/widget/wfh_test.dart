import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:redemption/data/repositories/journey_repository.dart';
import 'package:redemption/data/repositories/settings_repository.dart';
import 'package:redemption/data/repositories/tracker_repository.dart';
import 'package:redemption/domain/journey_upgrades.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/features/today/tracker_tile.dart';

import '../support/harness.dart';

void main() {
  // Monday morning: Left office (16:30) is still ahead.
  final monday = DateTime(2026, 10, 12, 10);

  testWidgets('answering "Work from home" takes Left office off the day', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env, now: monday));
    await settle(tester);
    final nextUp = find.textContaining(RegExp(r'Next up · \d+ left today'));
    await tester.ensureVisible(nextUp);
    final before = int.parse(
      RegExp(r'(\d+) left').firstMatch(tester.widget<Text>(nextUp).data!)![1]!,
    );

    await tester.tap(find.text('Today').last);
    await settle(tester);
    final leftOfficeTile = find.ancestor(
      of: find.text('Left office'),
      matching: find.byType(TrackerTile),
    );
    await tester.dragUntilVisible(
      find.text('Left office'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    expect(leftOfficeTile, findsOneWidget);

    await tester.dragUntilVisible(
      find.text('WFH or office?'),
      find.byType(CustomScrollView),
      const Offset(0, 200),
    );
    await settle(tester);
    final workTile = find.ancestor(
      of: find.text('WFH or office?'),
      matching: find.byType(TrackerTile),
    );
    await tester.tap(
      find.descendant(of: workTile, matching: find.byTooltip('Work from home')),
    );
    await settle(tester);

    // Gone from the timeline, listed as not needed (and still loggable).
    expect(leftOfficeTile, findsNothing);
    final notNeeded = find.textContaining('Not needed today');
    await tester.dragUntilVisible(
      notNeeded,
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await settle(tester);
    await tester.tap(notNeeded);
    await settle(tester);
    expect(find.text('Not needed — Work from home'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Not needed — Work from home'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await settle(tester);
    await tester.tap(find.text('Not needed — Work from home'));
    await settle(tester);
    expect(
      find.text(
        'Not needed on this day (Work from home) — logging is optional.',
      ),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(200, 40));
    await settle(tester);

    // Next up no longer waits for it.
    await tester.tap(find.text('Home').last);
    await settle(tester);
    await tester.ensureVisible(nextUp);
    final after = int.parse(
      RegExp(r'(\d+) left').firstMatch(tester.widget<Text>(nextUp).data!)![1]!,
    );
    expect(after, before - 2, reason: 'WFH answered, Left office not needed');
  });

  testWidgets('turning the rule off doesn\'t bring it back as "new"', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env, now: monday));
    await settle(tester);
    expect(find.text('New for your journey'), findsNothing);
    await tester.tap(find.text('Plan').last);
    await settle(tester);
    await tester.dragUntilVisible(
      find.text('Left office'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Left office'));
    await settle(tester);
    final skipSwitch = find.widgetWithText(
      SwitchListTile,
      'Not needed on certain days',
    );
    await tester.dragUntilVisible(
      skipSwitch,
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await settle(tester);
    await tester.tap(skipSwitch);
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    await tester.tap(find.text('Home').last);
    await settle(tester);
    expect(find.text('New for your journey'), findsNothing);
    final settings = (await tester.runAsync(
      () => SettingsRepository(env.db).load(),
    ))!;
    expect(
      settings.dismissedUpgrades,
      contains(JourneyUpgrade.leftOfficeSkipId),
    );
  });

  testWidgets('the tracker editor shows and edits the skip rule', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    late int leftOfficeId;
    await tester.runAsync(() async {
      final journey = (await JourneyRepository(env.db).active())!;
      final trackers = await TrackerRepository(env.db).forJourney(journey.id);
      leftOfficeId = trackers.firstWhere((t) => t.name == 'Left office').id;
    });

    await tester.pumpWidget(buildApp(env, now: monday));
    await settle(tester);
    await tester.tap(find.text('Plan').last);
    await settle(tester);
    await tester.dragUntilVisible(
      find.text('Left office'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Left office'));
    await settle(tester);

    final skipSwitch = find.widgetWithText(
      SwitchListTile,
      'Not needed on certain days',
    );
    await tester.dragUntilVisible(
      skipSwitch,
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    expect(tester.widget<SwitchListTile>(skipSwitch).value, isTrue);
    final leave = find.widgetWithText(FilterChip, '🌴  Leave / holiday');
    await tester.ensureVisible(leave);
    await settle(tester);
    expect(tester.widget<FilterChip>(leave).selected, isTrue);
    expect(
      tester
          .widget<FilterChip>(
            find.widgetWithText(FilterChip, '🏠  Work from home'),
          )
          .selected,
      isTrue,
    );
    // Leave days count again.
    await tester.tap(leave);
    await settle(tester);
    expect(tester.widget<FilterChip>(leave).selected, isFalse);
    await tester.tap(find.text('Save'));
    await settle(tester);

    final saved = (await tester.runAsync(
      () => TrackerRepository(env.db).forJourney(1),
    ))!.firstWhere((t) => t.id == leftOfficeId);
    expect(saved.config.skipRule?.whenOptionIds, ['wfh']);
  });
}
