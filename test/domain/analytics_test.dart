import 'package:flutter_test/flutter_test.dart';
import 'package:redemption/domain/analytics.dart';
import 'package:redemption/domain/models.dart';
import 'package:redemption/domain/neuro_phase.dart';
import 'package:redemption/domain/scoring.dart';
import 'package:redemption/domain/tracker_goal.dart';
import 'package:redemption/domain/tracker_type.dart';
import 'package:redemption/domain/tracker_value.dart';

import '../support/fixtures.dart';

void main() {
  const scoring = Scoring(dayStartMinutes: 180);

  group('JourneyStats', () {
    final t = tracker();

    JourneyStats stats(List<bool?> days, {int todayOffset = -1}) {
      final entries = [
        for (final (i, done) in days.indexed)
          if (done != null) entry(t.id, start.addDays(i), BoolValue(done)),
      ];
      return JourneyStats.compute(
        journey: journey(),
        trackers: [t],
        index: EntryIndex(entries),
        today: start.addDays(todayOffset < 0 ? days.length - 1 : todayOffset),
        scoring: scoring,
        threshold: 0.8,
      );
    }

    test('counts streaks, wins and perfect days', () {
      final s = stats([true, true, false, true, true, true]);
      expect(s.currentStreak, 3);
      expect(s.bestStreak, 3);
      expect(s.winDays, 5);
      expect(s.perfectDays, 5);
      expect(s.countedDays, 6);
      expect(s.consistency, closeTo(5 / 6, 1e-9));
      expect(s.dayNumber, 6);
      expect(s.daysLeft, 84);
    });

    test('an unfinished today never breaks the streak', () {
      final s = stats([true, true, true, null]);
      expect(s.currentStreak, 3, reason: 'today is still in progress');
      expect(s.countedDays, 3);
      expect(s.consistency, 1);
    });

    test('a completed today extends the streak immediately', () {
      final s = stats([true, true, true, true]);
      expect(s.currentStreak, 4);
    });

    test('missed past days break the streak', () {
      final s = stats([true, true, null, true, null]);
      expect(s.currentStreak, 1);
      expect(s.bestStreak, 2);
    });

    test('before the start date nothing is counted', () {
      final s = JourneyStats.compute(
        journey: journey(),
        trackers: [t],
        index: EntryIndex.empty,
        today: start.addDays(-3),
        scoring: scoring,
        threshold: 0.8,
      );
      expect(s.hasStarted, isFalse);
      expect(s.days, isEmpty);
      expect(s.dayNumber, 0);
    });
  });

  group('TrackerStats', () {
    test('planned days respect the weekday schedule', () {
      final weekdaysOnly = tracker(weekdays: Weekdays.workweek);
      final s = TrackerStats.compute(
        tracker: weekdaysOnly,
        journey: journey(days: 14),
        index: EntryIndex.empty,
        today: start,
        scoring: scoring,
      );
      expect(s.plannedDays, 10);
    });

    test('averages time on the day-relative axis', () {
      final sleep = tracker(type: TrackerType.time, goal: const LoggedGoal());
      final s = TrackerStats.compute(
        tracker: sleep,
        journey: journey(),
        index: EntryIndex([
          entry(sleep.id, start, const TimeValue(23 * 60 + 30)),
          entry(sleep.id, start.addDays(1), const TimeValue(30)),
        ]),
        today: start.addDays(2),
        scoring: scoring,
      );
      expect(
        s.average,
        0,
        reason: 'average of 23:30 and 00:30 is midnight, not noon',
      );
    });

    test('success rate, streak and choice distribution', () {
      final t = tracker();
      final s = TrackerStats.compute(
        tracker: t,
        journey: journey(),
        index: EntryIndex([
          entry(t.id, start, const BoolValue(true)),
          entry(t.id, start.addDays(1), const BoolValue(false)),
          entry(t.id, start.addDays(2), const BoolValue(true)),
        ]),
        today: start.addDays(2),
        scoring: scoring,
      );
      expect(s.expectedDays, 3);
      expect(s.doneDays, 2);
      expect(s.currentStreak, 1);
      expect(s.optionCounts, {'yes': 2, 'no': 1});
      expect(s.journeyProgress, closeTo(2 / 90, 1e-9));
    });
  });

  test('text suggestions are frequency ranked and de-duplicated', () {
    final t = tracker(type: TrackerType.longText, goal: const LoggedGoal());
    final index = EntryIndex([
      entry(t.id, start, const TextValue('Oats, eggs, dates')),
      entry(t.id, start.addDays(1), const TextValue('eggs, Banana')),
      entry(t.id, start.addDays(2), const TextValue('Eggs\nOats')),
    ]);
    final s = textSuggestions(t, index);
    expect(s.first, 'Eggs');
    expect(s.sublist(0, 2), containsAll(['Eggs', 'Oats']));
    expect(s, containsAll(['dates', 'Banana']));
    expect(s.length, 4);
  });

  test('series exposes chartable values with progress', () {
    final w = tracker(
      type: TrackerType.counter,
      goal: const NumberGoal(comparator: NumberComparator.atLeast, value: 8),
    );
    final series = buildSeries(
      tracker: w,
      index: EntryIndex([entry(w.id, start, const NumberValue(4))]),
      scoring: scoring,
      from: start,
      to: start.addDays(1),
    );
    expect(series.length, 2);
    expect(series.first.value, 4);
    expect(series.first.progress, 0.5);
    expect(series.last.value, isNull);
  });

  group('NeuroPhase', () {
    test('90-day boundaries follow 21 / 66 / 90', () {
      expect(NeuroPhase.boundaries(90), (21, 66));
      expect(
        NeuroPhase.forDay(dayNumber: 21, totalDays: 90).kind,
        NeuroPhaseKind.uproot,
      );
      expect(
        NeuroPhase.forDay(dayNumber: 22, totalDays: 90).kind,
        NeuroPhaseKind.rewire,
      );
      expect(
        NeuroPhase.forDay(dayNumber: 67, totalDays: 90).kind,
        NeuroPhaseKind.redeem,
      );
    });

    test('scales to other lengths', () {
      final (p1, p2) = NeuroPhase.boundaries(40);
      expect(p1, 9);
      expect(p2, 29);
      final last = NeuroPhase.forDay(dayNumber: 40, totalDays: 40);
      expect(last.kind, NeuroPhaseKind.redeem);
      expect(last.progress, 1);
    });
  });
}
