import 'package:flutter_test/flutter_test.dart';
import 'package:redemption/core/time/day.dart';
import 'package:redemption/domain/achievements.dart';
import 'package:redemption/domain/analytics.dart';
import 'package:redemption/domain/models.dart';
import 'package:redemption/domain/scoring.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/domain/tracker_config.dart';
import 'package:redemption/domain/tracker_goal.dart';
import 'package:redemption/domain/tracker_type.dart';
import 'package:redemption/domain/tracker_value.dart';

const start = Day(2026, 10, 1);
const scoring = Scoring(dayStartMinutes: 180);

Tracker tracker(
  int id,
  String name,
  TrackerType type, {
  TrackerConfig config = const TrackerConfig(),
  TrackerGoal goal = const LoggedGoal(),
}) => Tracker(
  id: id,
  journeyId: 1,
  name: name,
  type: type,
  icon: 'x',
  color: 0,
  activeFrom: start,
  config: config,
  goal: goal,
);

const prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

void main() {
  final work = tracker(
    1,
    'WFH or office?',
    TrackerType.singleChoice,
    config: const TrackerConfig(
      options: [
        ChoiceOption(id: 'wfh', label: 'Work from home'),
        ChoiceOption(id: 'office', label: 'Office'),
      ],
    ),
    goal: const ChoiceScoreGoal(),
  );
  final prayers = [
    for (final (i, name) in prayerNames.indexed)
      tracker(
        10 + i,
        name,
        TrackerType.singleChoice,
        config: TrackerConfig(
          options: prayerOptions,
          dayRule: name == 'Fajr' || name == 'Isha'
              ? null
              : officeDayRule(whenTrackerId: 1),
        ),
        goal: const ChoiceScoreGoal(),
      ),
  ];
  final workout = tracker(
    20,
    'Workout',
    TrackerType.checkbox,
    goal: const BoolGoal(),
  );
  final meals = [
    for (final (i, m) in ['Breakfast', 'Lunch'].indexed)
      tracker(
        30 + i,
        '$m on time?',
        TrackerType.checkbox,
        goal: const BoolGoal(),
      ),
  ];
  final all = [work, ...prayers, workout, ...meals];

  Entry e(Tracker t, TrackerValue v, {Day on = start}) => Entry(
    id: t.id * 1000 + on.difference(start),
    trackerId: t.id,
    day: on,
    value: v,
    updatedAt: DateTime(2026),
  );

  List<Achievement> dayOf(List<Entry> entries, {List<Tracker>? trackers}) {
    final index = EntryIndex(entries);
    final ts = trackers ?? all;
    return Achievements.forDay(
      start,
      summary: scoring.summarize(start, ts, index),
      trackers: ts,
      sameDay: index.forDay(start),
      scoring: scoring,
    );
  }

  List<Entry> prayed(List<String> options, {Day on = start}) => [
    for (final (i, p) in prayers.indexed) e(p, ChoiceValue(options[i]), on: on),
  ];

  group('prayers', () {
    test('all in congregation', () {
      expect(
        dayOf(prayed(List.filled(5, 'jamaah'))),
        contains(const Achievement('🕌', 'All 5 prayers in congregation')),
      );
    });

    test('all on time (some alone)', () {
      final a = dayOf(
        prayed(['jamaah', 'ontime', 'jamaah', 'jamaah', 'ontime']),
      );
      expect(a, contains(const Achievement('🤲', 'All 5 prayers on time')));
      expect(a.map((a) => a.emoji), isNot(contains('🕌')));
    });

    test('one late or missing: nothing', () {
      expect(
        dayOf(prayed(['jamaah', 'late', 'jamaah', 'jamaah', 'jamaah'])),
        isEmpty,
      );
      expect(dayOf(prayed(List.filled(5, 'jamaah')).sublist(1)), isEmpty);
    });

    test('office days: on time counts as congregation where no masjid', () {
      final a = dayOf([
        e(work, const ChoiceValue('office')),
        ...prayed(['jamaah', 'ontime', 'ontime', 'ontime', 'jamaah']),
      ]);
      expect(
        a,
        contains(const Achievement('🕌', 'All 5 prayers in congregation')),
      );
      // Fajr and Isha are at home: alone there is only "on time".
      final home = dayOf([
        e(work, const ChoiceValue('office')),
        ...prayed(['ontime', 'ontime', 'ontime', 'ontime', 'jamaah']),
      ]);
      expect(home.map((a) => a.emoji), contains('🤲'));
    });
  });

  test('every meal on time, the workout and custom emojis', () {
    final reading = tracker(
      40,
      'Quran',
      TrackerType.checkbox,
      config: const TrackerConfig(badge: '📖'),
      goal: const BoolGoal(),
    );
    final a = dayOf(
      [
        for (final m in meals) e(m, const BoolValue(true)),
        e(workout, const BoolValue(true)),
        e(reading, const BoolValue(true)),
      ],
      trackers: [...all, reading],
    );
    expect(a, [
      const Achievement('🍽️', 'Every meal on time'),
      const Achievement('💪', 'Workout'),
      const Achievement('📖', 'Quran'),
    ]);
    // A late meal or a skipped workout earns nothing.
    expect(
      dayOf([
        e(meals.first, const BoolValue(true)),
        e(workout, const BoolValue(false)),
      ]),
      isEmpty,
    );
  });

  test('an emoji turned off in the editor stays off', () {
    final noBadge = workout.copyWith(
      config: workout.config.copyWith(badge: () => ''),
    );
    expect(Achievements.badgeOf(workout), '💪', reason: 'default by name');
    expect(Achievements.badgeOf(noBadge), '');
    expect(
      dayOf([e(noBadge, const BoolValue(true))], trackers: [noBadge]),
      contains(Achievements.perfect),
      reason: 'still a perfect day, just no 💪',
    );
    expect(
      dayOf(
        [e(noBadge, const BoolValue(true))],
        trackers: [noBadge],
      ).map((a) => a.emoji),
      isNot(contains('💪')),
    );
  });

  test('a perfect day shows its star (and a streak), not every detail', () {
    const day = [
      Achievements.perfect,
      Achievement('🔥', '7-day streak'),
      Achievement('🕌', 'All 5 prayers in congregation'),
      Achievement('💪', 'Workout'),
    ];
    expect(Achievements.cellEmojis(day), ['🌟', '🔥']);
    expect(
      Achievements.cellEmojis([
        const Achievement('🕌', 'x'),
        const Achievement('🍽️', 'y'),
        const Achievement('💪', 'z'),
        const Achievement('🌙', 'w'),
      ], max: 2),
      ['🕌', '🍽️'],
    );
  });

  test('win streaks are celebrated on milestone days', () {
    expect(
      [
        for (var n = 1; n <= 200; n++)
          if (Achievements.isMilestone(n)) n,
      ],
      [3, 7, 14, 21, 30, 40, 50, 60, 66, 75, 90, 120, 150, 180],
    );
    final journey = Journey(
      id: 1,
      name: '90',
      intention: '',
      startDay: start,
      durationDays: 90,
      isActive: true,
      createdAt: DateTime(2026),
    );
    // Trained every day but the 5th: streaks of 4 then 3 more.
    final index = EntryIndex([
      for (var i = 0; i < 9; i++)
        e(workout, BoolValue(i != 4), on: start.addDays(i)),
    ]);
    final today = start.addDays(9);
    final stats = JourneyStats.compute(
      journey: journey,
      trackers: [workout],
      index: index,
      today: today,
      scoring: scoring,
      threshold: 0.8,
    );
    final map = Achievements.forJourney(
      stats: stats,
      trackers: [workout],
      index: index,
      scoring: scoring,
      threshold: 0.8,
    );
    String? streakOn(int i) =>
        map[start.addDays(i)]?.where((a) => a.emoji == '🔥').firstOrNull?.label;
    expect(streakOn(2), '3-day streak');
    expect(streakOn(3), isNull);
    expect(streakOn(7), '3-day streak', reason: 'after the broken day');
    expect(map[start.addDays(4)], isNull, reason: 'missed: nothing earned');
    expect(map[today], isNull, reason: 'unfinished today');
  });

  test('the emoji is saved with the tracker and older configs default', () {
    expect(TrackerConfig.fromJson(const {}).badge, isNull);
    expect(const TrackerConfig().toJson(), isNot(contains('badge')));
    for (final b in ['', '📖']) {
      expect(TrackerConfig.fromJson(TrackerConfig(badge: b).toJson()).badge, b);
    }
  });
}
