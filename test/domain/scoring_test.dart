import 'package:flutter_test/flutter_test.dart';
import 'package:redemption/domain/models.dart';
import 'package:redemption/domain/scoring.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/domain/tracker_config.dart';
import 'package:redemption/domain/tracker_goal.dart';
import 'package:redemption/domain/tracker_type.dart';
import 'package:redemption/domain/tracker_value.dart';

import '../support/fixtures.dart';

void main() {
  const scoring = Scoring(dayStartMinutes: 180);

  group('progress', () {
    test('nothing logged earns nothing', () {
      expect(scoring.progress(tracker(), null), 0);
      expect(
        scoring.progress(
          tracker(type: TrackerType.text, goal: const LoggedGoal()),
          const TextValue('  '),
        ),
        0,
      );
    });

    test('bool goals support build and quit habits', () {
      expect(scoring.progress(tracker(), const BoolValue(true)), 1);
      expect(scoring.progress(tracker(), const BoolValue(false)), 0);
      final quit = tracker(goal: const BoolGoal(target: false));
      expect(scoring.progress(quit, const BoolValue(false)), 1);
      expect(scoring.progress(quit, const BoolValue(true)), 0);
    });

    test('choice options carry their own credit (prayer quality)', () {
      final fajr = tracker(
        type: TrackerType.singleChoice,
        goal: const ChoiceScoreGoal(),
        config: const TrackerConfig(options: prayerOptions),
      );
      expect(scoring.progress(fajr, const ChoiceValue('jamaah')), 1);
      expect(scoring.progress(fajr, const ChoiceValue('late')), 0.5);
      expect(scoring.progress(fajr, const ChoiceValue('missed')), 0);
      expect(scoring.progress(fajr, const ChoiceValue('deleted-option')), 0);
    });

    test('at-least goals give partial credit and cap at 100%', () {
      final water = tracker(
        type: TrackerType.counter,
        goal: const NumberGoal(comparator: NumberComparator.atLeast, value: 8),
      );
      expect(scoring.progress(water, const NumberValue(6)), 0.75);
      expect(scoring.progress(water, const NumberValue(12)), 1);
    });

    test('at-most and between goals are pass/fail', () {
      final screen = tracker(
        type: TrackerType.duration,
        goal: const NumberGoal(comparator: NumberComparator.atMost, value: 60),
      );
      expect(scoring.progress(screen, const DurationValue(45)), 1);
      expect(scoring.progress(screen, const DurationValue(61)), 0);
      final weight = tracker(
        type: TrackerType.decimal,
        goal: const NumberGoal(
          comparator: NumberComparator.between,
          value: 70,
          upper: 72.5,
        ),
      );
      expect(scoring.progress(weight, const NumberValue(72.5)), 1);
      expect(scoring.progress(weight, const NumberValue(73)), 0);
    });

    test('time goals compare on the day-relative axis with grace', () {
      final wake = tracker(
        type: TrackerType.time,
        goal: const TimeGoal(
          comparator: TimeComparator.before,
          minutes: 5 * 60,
          graceMinutes: 15,
        ),
      );
      expect(scoring.progress(wake, const TimeValue(4 * 60 + 50)), 1);
      expect(scoring.progress(wake, const TimeValue(5 * 60 + 10)), 0.5);
      expect(scoring.progress(wake, const TimeValue(5 * 60 + 30)), 0);

      // Sleep before 22:30 — 00:30 is LATER than 22:30, not earlier.
      final sleep = tracker(
        type: TrackerType.time,
        goal: const TimeGoal(
          comparator: TimeComparator.before,
          minutes: 22 * 60 + 30,
        ),
      );
      expect(scoring.progress(sleep, const TimeValue(22 * 60)), 1);
      expect(scoring.progress(sleep, const TimeValue(30)), 0);
    });

    test('multi-choice and attachments count items for numeric goals', () {
      final multi = tracker(
        type: TrackerType.multiChoice,
        goal: const NumberGoal(comparator: NumberComparator.atLeast, value: 2),
      );
      expect(scoring.progress(multi, const MultiChoiceValue(['a'])), 0.5);
      expect(scoring.progress(multi, const MultiChoiceValue(['a', 'b'])), 1);
    });
  });

  group('status', () {
    final t = tracker(weekdays: Weekdays.workweek);
    final saturday = start.addDays(2); // 2026-10-03
    final friday = start.addDays(1);

    test('pending today, missed in the past', () {
      expect(scoring.status(t, null, friday, friday), EntryStatus.pending);
      expect(
        scoring.status(t, null, friday, friday.addDays(3)),
        EntryStatus.missed,
      );
    });

    test('not expected on unscheduled days', () {
      expect(
        scoring.status(t, null, saturday, saturday),
        EntryStatus.notExpected,
      );
    });

    test('done / failed from the logged value', () {
      expect(
        scoring.status(
          t,
          entry(1, friday, const BoolValue(true)),
          friday,
          friday,
        ),
        EntryStatus.done,
      );
      expect(
        scoring.status(
          t,
          entry(1, friday, const BoolValue(false)),
          friday,
          friday,
        ),
        EntryStatus.failed,
      );
    });
  });

  group('day summary', () {
    test('averages credit over required, expected trackers only', () {
      final trackers = [
        tracker(),
        tracker(
          id: 2,
          type: TrackerType.counter,
          goal: const NumberGoal(
            comparator: NumberComparator.atLeast,
            value: 4,
          ),
        ),
        tracker(id: 3, isRequired: false),
        tracker(id: 4, activeFrom: start.addDays(5)),
      ];
      final index = EntryIndex([
        entry(1, start, const BoolValue(true)),
        entry(2, start, const NumberValue(2)),
        entry(3, start, const BoolValue(false)),
      ]);
      final s = scoring.summarize(start, trackers, index);
      expect(s.expected, 2);
      expect(s.done, 1);
      expect(s.score, closeTo(0.75, 1e-9));
      expect(s.isWin(0.8), isFalse);
      expect(s.isWin(0.75), isTrue);
    });

    test('a day with nothing required is a rest day', () {
      final s = scoring.summarize(start, [
        tracker(isRequired: false),
      ], EntryIndex.empty);
      expect(s.isRestDay, isTrue);
      expect(s.isWin(0.5), isFalse);
    });
  });
}
