import 'package:flutter_test/flutter_test.dart';
import 'package:redemption/core/time/day.dart';
import 'package:redemption/domain/app_settings.dart';
import 'package:redemption/domain/models.dart';
import 'package:redemption/domain/sleep_cycles.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/domain/tracker_config.dart';
import 'package:redemption/domain/tracker_type.dart';

void main() {
  String hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  test('wake-up times fall on full 90-minute cycles from bedtime', () {
    final times = SleepCycles.wakeTimes(DateTime(2026, 10, 12, 22, 41));
    expect(times.map((w) => w.cycles), [1, 2, 3, 4, 5, 6]);
    expect(times.map((w) => hm(w.at)), [
      '00:11',
      '01:41',
      '03:11',
      '04:41',
      '06:11',
      '07:41',
    ]);
    expect(times.last.at.day, 13, reason: 'the next morning');
    expect(times.map((w) => w.sleepMinutes), [90, 180, 270, 360, 450, 540]);
    expect(
      [
        for (final w in times)
          if (w.isRecommended) w.cycles,
      ],
      [5, 6],
      reason: '7½–9 hours',
    );
  });

  test('the time it takes to fall asleep shifts every cycle', () {
    final times = SleepCycles.wakeTimes(
      DateTime(2026, 10, 12, 22, 41),
      fallAsleepMinutes: 15,
    );
    expect(hm(times.first.at), '00:26');
    expect(hm(times[4].at), '06:26');
  });

  test('a bedtime before the day starts belongs to the night before', () {
    const monday = Day(2026, 10, 12);
    expect(
      SleepCycles.bedtimeOn(monday, 22 * 60 + 41, dayStartMinutes: 180),
      DateTime(2026, 10, 12, 22, 41),
    );
    expect(
      SleepCycles.bedtimeOn(monday, 30, dayStartMinutes: 180),
      DateTime(2026, 10, 13, 0, 30),
    );
  });

  group('which trackers suggest wake-up times', () {
    Tracker time(String name, {bool? flag, TrackerType? type}) => Tracker(
      id: 1,
      journeyId: 1,
      name: name,
      type: type ?? TrackerType.time,
      icon: 'bed',
      color: 0,
      activeFrom: const Day(2026, 10, 1),
      config: TrackerConfig(suggestWakeTimes: flag),
    );

    test('bedtime names by default, the editor switch decides otherwise', () {
      for (final name in [
        'Sleep time',
        'Bedtime',
        'Went to bed',
        'Asleep by',
      ]) {
        expect(time(name).suggestsWakeTimes, isTrue, reason: name);
      }
      for (final name in ['Wake-up time', 'Left office', 'Fajr']) {
        expect(time(name).suggestsWakeTimes, isFalse, reason: name);
      }
      expect(time('Sleep time', flag: false).suggestsWakeTimes, isFalse);
      expect(time('Lights out', flag: true).suggestsWakeTimes, isTrue);
      expect(
        time('Sleep', type: TrackerType.duration).suggestsWakeTimes,
        isFalse,
        reason: 'only time trackers log a bedtime',
      );
    });

    test('the flag round-trips and older configs leave it to the name', () {
      expect(TrackerConfig.fromJson(const {}).suggestWakeTimes, isNull);
      expect(const TrackerConfig().toJson(), isNot(contains('wakeTimes')));
      for (final v in [true, false]) {
        final config = TrackerConfig(suggestWakeTimes: v);
        expect(TrackerConfig.fromJson(config.toJson()).suggestWakeTimes, v);
      }
    });

    test('the template\'s Sleep time suggests them', () {
      final sleep = Templates.redemption.trackers
          .firstWhere((t) => t.tracker.name == 'Sleep time')
          .tracker;
      expect(sleep.config.suggestWakeTimes, isTrue);
      expect(sleep.suggestsWakeTimes, isTrue);
    });
  });

  test('the time to fall asleep is a saved setting', () {
    expect(const AppSettings().fallAsleepMinutes, 0);
    final s = const AppSettings().copyWith(fallAsleepMinutes: 15);
    expect(AppSettings.fromMap(s.toMap()).fallAsleepMinutes, 15);
    expect(AppSettings.fromMap(const {}).fallAsleepMinutes, 0);
  });
}
