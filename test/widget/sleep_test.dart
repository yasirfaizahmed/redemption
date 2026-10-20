import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:redemption/core/time/day.dart';
import 'package:redemption/data/repositories/entry_repository.dart';
import 'package:redemption/data/repositories/journey_repository.dart';
import 'package:redemption/data/repositories/settings_repository.dart';
import 'package:redemption/data/repositories/tracker_repository.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/domain/tracker_value.dart';
import 'package:redemption/features/today/tracker_tile.dart';
import 'package:redemption/services/alarm_service.dart';
import 'package:redemption/state/providers.dart';

import '../support/harness.dart';

class _FakeAlarm extends AlarmService {
  _FakeAlarm({this.works = true});
  final bool works;
  final calls = <(int, int, String)>[];

  @override
  bool get isSupported => true;

  @override
  Future<bool> setAlarm({
    required int hour,
    required int minute,
    required String message,
  }) async {
    calls.add((hour, minute, message));
    return works;
  }
}

void main() {
  // Monday, 22:10 — time for bed.
  final bedtime = DateTime(2026, 10, 12, 22, 10);

  Future<void> scrollTo(WidgetTester tester, String text) async {
    await tester.dragUntilVisible(
      find.text(text),
      find.byType(CustomScrollView),
      const Offset(0, -250),
    );
    await settle(tester);
  }

  Finder nowOn(String name) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(TrackerTile)),
    matching: find.text('Now'),
  );

  testWidgets('"Now" on Sleep time offers alarms on full sleep cycles', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    final alarm = _FakeAlarm();

    await tester.pumpWidget(
      buildApp(
        env,
        now: bedtime,
        overrides: [alarmServiceProvider.overrideWithValue(alarm)],
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);
    await scrollTo(tester, 'Sleep time');
    await tester.tap(nowOn('Sleep time'));
    await settle(tester);

    expect(find.text('Sleep well'), findsOneWidget);
    expect(find.text('Bedtime logged at 22:10'), findsOneWidget);
    for (final t in ['23:40', '01:10', '02:40', '04:10', '05:40', '07:10']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.textContaining('Recommended'), findsNWidgets(2));
    expect(
      find.text('5 cycles · 7h 30m of sleep · Recommended'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('05:40'));
    await settle(tester);
    await tester.tap(find.text('05:40'));
    await settle(tester);
    expect(alarm.calls, [(5, 40, 'Wake up · 5 sleep cycles')]);
    expect(find.text('Alarm set for 05:40 in your Clock app.'), findsOneWidget);
    expect(
      find.text('5 cycles · 7h 30m of sleep · Recommended · alarm set'),
      findsOneWidget,
    );

    // A second pick adds a second alarm; both stay marked.
    await tester.ensureVisible(find.text('07:10'));
    await settle(tester);
    await tester.tap(find.text('07:10'));
    await settle(tester);
    expect(alarm.calls.last, (7, 10, 'Wake up · 6 sleep cycles'));
    expect(find.textContaining('· alarm set'), findsNWidgets(2));
    expect(
      find.text(
        'Alarms on in your Clock app: 05:40, 07:10. Turn off any you '
        'don’t need there.',
      ),
      findsOneWidget,
    );

    // Taking 15 minutes to fall asleep moves every time, and is remembered.
    await tester.ensureVisible(find.text('15 min'));
    await settle(tester);
    await tester.tap(find.text('15 min'));
    await settle(tester);
    expect(find.text('05:55'), findsOneWidget);
    expect(find.text('05:40'), findsNothing);
    final settings = (await tester.runAsync(
      () => SettingsRepository(env.db).load(),
    ))!;
    expect(settings.fallAsleepMinutes, 15);

    // The bedtime itself was logged.
    final entries = (await tester.runAsync(
      () => EntryRepository(env.db).watchForJourney(1).first,
    ))!;
    expect(
      entries.map((e) => e.value),
      contains(const TimeValue(22 * 60 + 10)),
    );
  });

  testWidgets('other time trackers just log the time', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env, now: bedtime));
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);
    await tester.dragUntilVisible(
      find.text('Wake-up time'),
      find.byType(CustomScrollView),
      const Offset(0, 250),
    );
    await settle(tester);
    await tester.tap(nowOn('Wake-up time'));
    await settle(tester);
    expect(find.text('Sleep well'), findsNothing);
    expect(find.text('Wake up fresh'), findsNothing);
  });

  testWidgets('the Sleep time sheet shows wake-up times for today\'s '
      'bedtime', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    await tester.runAsync(() async {
      final journey = (await JourneyRepository(env.db).active())!;
      final sleep = (await TrackerRepository(env.db).forJourney(journey.id))
          .firstWhere((t) => t.name == 'Sleep time');
      await EntryRepository(env.db).upsert(
        trackerId: sleep.id,
        day: const Day(2026, 10, 12),
        value: const TimeValue(22 * 60 + 30),
      );
    });

    await tester.pumpWidget(buildApp(env, now: bedtime));
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);
    await scrollTo(tester, 'Sleep time');
    await tester.tap(find.text('Sleep time'));
    await settle(tester);

    final wake = find.text('Wake up fresh');
    await tester.dragUntilVisible(
      wake,
      find.byType(SingleChildScrollView).last,
      const Offset(0, -250),
    );
    expect(wake, findsOneWidget);
    expect(find.text('06:00'), findsOneWidget, reason: '22:30 + 5 cycles');
  });

  testWidgets('the editor switch turns wake-up times off', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env, now: bedtime));
    await settle(tester);
    await tester.tap(find.text('Plan').last);
    await settle(tester);
    await scrollTo(tester, 'Sleep time');
    await tester.tap(find.text('Sleep time'));
    await settle(tester);
    final toggle = find.widgetWithText(SwitchListTile, 'Suggest wake-up times');
    await tester.dragUntilVisible(
      toggle,
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await settle(tester);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    await tester.tap(toggle);
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    final sleep = (await tester.runAsync(
      () => TrackerRepository(env.db).forJourney(1),
    ))!.firstWhere((t) => t.name == 'Sleep time');
    expect(sleep.config.suggestWakeTimes, isFalse);
    expect(sleep.suggestsWakeTimes, isFalse);
  });

  testWidgets('times a day or more away can\'t be set (the Clock app would '
      'ring too soon)', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    final alarm = _FakeAlarm();

    // Up for Fajr: the sheet plans tonight's 22:00 bedtime.
    await tester.pumpWidget(
      buildApp(
        env,
        now: DateTime(2026, 10, 13, 5),
        overrides: [alarmServiceProvider.overrideWithValue(alarm)],
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);
    await scrollTo(tester, 'Sleep time');
    await tester.tap(find.text('Sleep time'));
    await settle(tester);
    final far = find.textContaining('over a day away');
    await tester.dragUntilVisible(
      find.text('05:30'),
      find.byType(SingleChildScrollView).last,
      const Offset(0, -250),
    );
    await settle(tester);
    expect(far, findsNWidgets(2), reason: '05:30 and 07:00 tomorrow');
    await tester.tap(find.text('05:30'), warnIfMissed: false);
    await settle(tester);
    expect(alarm.calls, isEmpty);
    // 04:00 tomorrow is 23 hours away: fine.
    await tester.ensureVisible(find.text('04:00'));
    await settle(tester);
    await tester.tap(find.text('04:00'));
    await settle(tester);
    expect(alarm.calls, [(4, 0, 'Wake up · 4 sleep cycles')]);
  });

  testWidgets('a failed alarm says so on the tapped time', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(
      buildApp(
        env,
        now: bedtime,
        overrides: [
          alarmServiceProvider.overrideWithValue(_FakeAlarm(works: false)),
        ],
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);
    await scrollTo(tester, 'Sleep time');
    await tester.tap(nowOn('Sleep time'));
    await settle(tester);
    await tester.tap(find.text('01:10'));
    await settle(tester);
    expect(
      find.text(
        '2 cycles · 3h of sleep · couldn’t reach the Clock app — set it '
        'yourself',
      ),
      findsOneWidget,
    );
  });

  testWidgets('without a Clock app to talk to, the times are a guide', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));

    // The test platform isn't Android: the real service can't set alarms.
    await tester.pumpWidget(buildApp(env, now: bedtime));
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);
    await scrollTo(tester, 'Sleep time');
    await tester.tap(nowOn('Sleep time'));
    await settle(tester);
    expect(
      find.textContaining('Set your alarm for one of these times.'),
      findsOneWidget,
    );
    await tester.tap(find.text('01:10'));
    await settle(tester);
    expect(find.textContaining('Clock app'), findsNothing);
  });

  testWidgets('the sheet covers the tabs and survives large text', (
    tester,
  ) async {
    usePhoneSurface(tester, textScale: 2);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(
      buildApp(
        env,
        now: bedtime,
        overrides: [alarmServiceProvider.overrideWithValue(_FakeAlarm())],
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);
    await scrollTo(tester, 'Sleep time');
    await tester.tap(nowOn('Sleep time'));
    await settle(tester);
    expect(find.text('Sleep well'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('Plan').hitTestable(), findsNothing);
  });

  testWidgets('a new time tracker named like a bedtime starts with wake-up '
      'times on, and saves what the switch showed', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.blank);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env, now: bedtime));
    await settle(tester);
    await tester.tap(find.text('Plan').last);
    await settle(tester);
    await tester.tap(find.text('New tracker'));
    await settle(tester);
    await tester.tap(find.text('Time of day'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Bedtime',
    );
    await settle(tester);
    final toggle = find.widgetWithText(SwitchListTile, 'Suggest wake-up times');
    await tester.dragUntilVisible(
      toggle,
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await settle(tester);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    await tester.tap(find.text('Save'));
    await settle(tester);

    final journey = (await tester.runAsync(
      () => JourneyRepository(env.db).active(),
    ))!;
    final saved = (await tester.runAsync(
      () => TrackerRepository(env.db).forJourney(journey.id),
    ))!.single;
    expect(saved.config.suggestWakeTimes, isTrue);
  });
}
