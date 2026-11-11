import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:redemption/data/repositories/settings_repository.dart';
import 'package:redemption/domain/math_challenge.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/features/alarm/alarm_ring_screen.dart';
import 'package:redemption/features/today/tracker_tile.dart';
import 'package:redemption/services/wake_alarm_service.dart';
import 'package:redemption/state/providers.dart';

import '../support/harness.dart';

/// An alarm service that rings on demand.
class FakeWakeAlarms implements WakeAlarmService {
  final _ringing = StreamController<List<WakeAlarm>>.broadcast();
  final _scheduled = StreamController<List<WakeAlarm>>.broadcast();
  var ringingNow = <WakeAlarm>[];
  var scheduledNow = <WakeAlarm>[];
  final stopped = <int>[];
  final cancelled = <int>[];

  @override
  bool get isSupported => true;

  void ring(WakeAlarm a) {
    scheduledNow = [
      for (final s in scheduledNow)
        if (s.id != a.id) s,
    ];
    ringingNow = [...ringingNow, a];
    _ringing.add(ringingNow);
    _scheduled.add(scheduledNow);
  }

  @override
  Stream<List<WakeAlarm>> get ringing async* {
    yield ringingNow;
    yield* _ringing.stream;
  }

  @override
  Stream<List<WakeAlarm>> get scheduled async* {
    yield scheduledNow;
    yield* _scheduled.stream;
  }

  @override
  Future<bool> schedule(DateTime at, {String label = ''}) async {
    final a = WakeAlarm(id: WakeAlarm.idFor(at), at: at, label: label);
    scheduledNow = [
      for (final s in scheduledNow)
        if (s.id != a.id) s,
      a,
    ];
    _scheduled.add(scheduledNow);
    return true;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduledNow = [
      for (final s in scheduledNow)
        if (s.id != id) s,
    ];
    _scheduled.add(scheduledNow);
  }

  @override
  Future<bool> stop(int id) async {
    stopped.add(id);
    ringingNow = [
      for (final r in ringingNow)
        if (r.id != id) r,
    ];
    _ringing.add(ringingNow);
    return true;
  }

  @override
  Future<AlarmChecks> checks() async => const AlarmChecks(
    notifications: true,
    fullScreen: true,
    guard: false,
    batteryUnrestricted: false,
  );

  @override
  Future<void> openSystemSetting(String which) async {}

  var ended = 0;
  var shown = 0;

  @override
  Future<void> sumsShown() async => shown++;

  @override
  Future<void> ringingEnded() async => ended++;
}

void main() {
  final bedtime = DateTime(2026, 10, 12, 22, 10);

  Future<void> type(WidgetTester tester, String answer) async {
    for (final d in answer.split('')) {
      await tester.tap(find.text(d).last);
      await tester.pump();
    }
    await tester.tap(find.bySemanticsLabel('Check answer'));
    await settle(tester);
  }

  /// The sums the ring screen will ask, with the same seed.
  List<MathProblem> expected(int count) =>
      MathChallenge.generateAll(Random(42), MathDifficulty.hard, count);

  testWidgets('a ringing alarm covers the app until its sum is solved', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    final alarms = FakeWakeAlarms();

    await tester.pumpWidget(
      buildApp(
        env,
        now: bedtime,
        overrides: [
          wakeAlarmServiceProvider.overrideWithValue(alarms),
          alarmRandomProvider.overrideWithValue(Random(42)),
        ],
      ),
    );
    await settle(tester);
    alarms.ring(WakeAlarm(id: 7, at: bedtime, label: '5 sleep cycles'));
    await settle(tester);

    final problem = expected(1).single;
    expect(find.text('Time to wake up'), findsOneWidget);
    expect(find.text('${problem.text} = ?'), findsOneWidget);
    expect(find.text('5 sleep cycles'), findsOneWidget);

    // Back does nothing; the app underneath can't be reached.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Time to wake up'), findsOneWidget);

    // A wrong answer keeps it ringing.
    await type(tester, '${problem.answer + 1}');
    expect(alarms.stopped, isEmpty);
    expect(find.text('Not right — try again'), findsOneWidget);

    await type(tester, '${problem.answer}');
    expect(alarms.stopped, [7]);
    expect(alarms.ended, 1, reason: 'no longer over the lock screen');
    expect(find.text('Time to wake up'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back while ringing never pops the page underneath', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    final alarms = FakeWakeAlarms();
    await tester.pumpWidget(
      buildApp(
        env,
        now: bedtime,
        overrides: [
          wakeAlarmServiceProvider.overrideWithValue(alarms),
          alarmRandomProvider.overrideWithValue(Random(42)),
        ],
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);
    expect(find.text('Ring in Redemption'), findsNothing);
    final settingsTitle = find.text('Settings');
    expect(settingsTitle, findsWidgets);

    alarms.ring(WakeAlarm(id: 3, at: bedtime));
    await settle(tester);
    expect(alarms.shown, 1, reason: 'the guard may act only once sums show');
    for (var i = 0; i < 3; i++) {
      await tester.binding.handlePopRoute();
      await settle(tester);
    }
    expect(find.text('Time to wake up'), findsOneWidget);

    await type(tester, '${expected(1).single.answer}');
    expect(find.text('Time to wake up'), findsNothing);
    expect(settingsTitle, findsWidgets, reason: 'still on Settings');
    expect(find.byTooltip('Settings'), findsNothing, reason: 'not home');
    expect(tester.takeException(), isNull);
  });

  testWidgets('with three sums, all three must be solved', (tester) async {
    usePhoneSurface(tester, textScale: 1.3);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    await tester.runAsync(() async {
      final repo = SettingsRepository(env.db);
      await repo.save((await repo.load()).copyWith(alarmMathCount: 3));
    });
    final alarms = FakeWakeAlarms();
    await tester.pumpWidget(
      buildApp(
        env,
        now: bedtime,
        overrides: [
          wakeAlarmServiceProvider.overrideWithValue(alarms),
          alarmRandomProvider.overrideWithValue(Random(42)),
        ],
      ),
    );
    await settle(tester);
    alarms.ring(WakeAlarm(id: 9, at: bedtime));
    await settle(tester);

    final problems = expected(3);
    for (final (i, p) in problems.indexed) {
      expect(
        find.text('Solve to stop the alarm · ${i + 1} of 3'),
        findsOneWidget,
      );
      expect(alarms.stopped, isEmpty);
      await type(tester, '${p.answer}');
    }
    expect(alarms.stopped, [9]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wake-up time sets the alarm in Redemption, and tapping it '
      'again cancels it', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    final alarms = FakeWakeAlarms();

    await tester.pumpWidget(
      buildApp(
        env,
        now: bedtime,
        overrides: [wakeAlarmServiceProvider.overrideWithValue(alarms)],
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);
    await tester.dragUntilVisible(
      find.text('Sleep time'),
      find.byType(CustomScrollView),
      const Offset(0, -250),
    );
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Sleep time'),
          matching: find.byType(TrackerTile),
        ),
        matching: find.text('Now'),
      ),
    );
    await settle(tester);

    expect(find.textContaining('rings until you solve a sum'), findsOneWidget);
    await tester.ensureVisible(find.text('05:40'));
    await settle(tester);
    await tester.tap(find.text('05:40'));
    await settle(tester);
    expect(alarms.scheduledNow.single.at, DateTime(2026, 10, 13, 5, 40));
    expect(alarms.scheduledNow.single.label, '5 sleep cycles');
    expect(find.textContaining('· alarm set'), findsOneWidget);

    await tester.tap(find.text('05:40'));
    await settle(tester);
    await tester.tap(find.text('Cancel alarm'));
    await settle(tester);
    expect(alarms.scheduledNow, isEmpty);
    expect(find.textContaining('· alarm set'), findsNothing);
  });

  testWidgets('settings show the alarm, its sums and what still needs fixing', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    final alarms = FakeWakeAlarms();
    await alarms.schedule(
      DateTime(2026, 10, 13, 5, 40),
      label: '5 sleep cycles',
    );

    await tester.pumpWidget(
      buildApp(
        env,
        now: bedtime,
        overrides: [wakeAlarmServiceProvider.overrideWithValue(alarms)],
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);
    await tester.dragUntilVisible(
      find.text('Ring in Redemption'),
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    await settle(tester);
    await tester.tap(find.text('Very hard'));
    await settle(tester);
    expect(
      find.text('e.g. ${MathDifficulty.veryHard.example}'),
      findsOneWidget,
    );

    await tester.dragUntilVisible(
      find.text('Alarm guard'),
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    await settle(tester);
    expect(find.text('5 sleep cycles'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Alarm guard'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('Fix'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
