import '../core/time/day.dart';
import '../core/time/time_of_day_x.dart';
import 'models.dart';
import 'tracker_goal.dart';
import 'tracker_value.dart';

/// Visual/semantic state of a tracker on a given day.
enum EntryStatus {
  /// Expected today, not logged yet.
  pending,

  /// Goal fully met.
  done,

  /// Logged with partial credit (e.g. 5/8 glasses, late prayer).
  partial,

  /// Logged, but the goal was not met (e.g. "Missed", or slept too late).
  failed,

  /// Expected on a past day and never logged.
  missed,

  /// Not scheduled / not active on that day, or switched off by a skip
  /// rule (e.g. "Left office" on a work-from-home day).
  notExpected,
}

/// Pure scoring rules. Stateless and fully unit-tested.
class Scoring {
  const Scoring({required this.dayStartMinutes});

  final int dayStartMinutes;

  static const _epsilon = 1e-9;

  static bool isComplete(double progress) => progress >= 1 - _epsilon;

  /// Credit (0–1) earned by [value] against [tracker]'s goal. [sameDay]
  /// holds the other entries of that day, for trackers with a [DayRule].
  double progress(
    Tracker tracker,
    TrackerValue? value, {
    Map<int, Entry> sameDay = const {},
  }) {
    if (value == null || value.isEmpty) return 0;
    final goal = tracker.goal;
    switch (goal) {
      case LoggedGoal():
        return 1;
      case BoolGoal(:final target):
        if (value is! BoolValue) return 1;
        return value.value == target ? 1 : 0;
      case ChoiceScoreGoal():
        if (value is! ChoiceValue) return 1;
        final override = tracker.ruleOn(sameDay)?.credits[value.optionId];
        if (override != null) return override.clamp(0, 1).toDouble();
        final option = tracker.config.optionById(value.optionId);
        return (option?.score ?? 0).clamp(0, 1).toDouble();
      case NumberGoal(:final comparator, value: final target, :final upper):
        final n = numericValue(tracker, value);
        if (n == null) return 1;
        switch (comparator) {
          case NumberComparator.atLeast:
            if (target <= 0) return 1;
            return (n / target).clamp(0, 1).toDouble();
          case NumberComparator.atMost:
            return n <= target + _epsilon ? 1 : 0;
          case NumberComparator.between:
            final hi = upper ?? target;
            return n >= target - _epsilon && n <= hi + _epsilon ? 1 : 0;
        }
      case TimeGoal(:final comparator, :final minutes, :final graceMinutes):
        if (value is! TimeValue) return 1;
        final actual = Clock.relativeToDayStart(value.minutes, dayStartMinutes);
        final target = Clock.relativeToDayStart(minutes, dayStartMinutes);
        final delta = comparator == TimeComparator.before
            ? actual - target
            : target - actual;
        if (delta <= 0) return 1;
        if (graceMinutes > 0 && delta <= graceMinutes) return 0.5;
        return 0;
    }
  }

  /// A comparable number for goals and charts, or null when not numeric.
  double? numericValue(Tracker tracker, TrackerValue value) => switch (value) {
    NumberValue(:final value) => value,
    DurationValue(:final minutes) => minutes.toDouble(),
    TimeValue(:final minutes) => Clock.relativeToDayStart(
      minutes,
      dayStartMinutes,
    ).toDouble(),
    MultiChoiceValue(:final optionIds) => optionIds.length.toDouble(),
    AttachmentsValue(:final files) => files.length.toDouble(),
    BoolValue(:final value) => value ? 1 : 0,
    ChoiceValue() || TextValue() => null,
  };

  EntryStatus status(
    Tracker tracker,
    Entry? entry,
    Day day,
    Day today, {
    Map<int, Entry> sameDay = const {},
  }) {
    final logged = entry != null && !entry.value.isEmpty;
    if (!tracker.isExpectedOn(day, sameDay: sameDay) && !logged) {
      return EntryStatus.notExpected;
    }
    if (!logged) {
      return day.isBefore(today) ? EntryStatus.missed : EntryStatus.pending;
    }
    final p = progress(tracker, entry.value, sameDay: sameDay);
    if (isComplete(p)) return EntryStatus.done;
    if (p > 0) return EntryStatus.partial;
    return EntryStatus.failed;
  }

  /// Score of a single day across all trackers that count on it.
  DaySummary summarize(Day day, List<Tracker> trackers, EntryIndex index) {
    var expected = 0;
    var earned = 0.0;
    var done = 0;
    var logged = 0;
    final entries = index.forDay(day);
    for (final t in trackers) {
      if (!t.countsOn(day, sameDay: entries)) continue;
      expected++;
      final e = entries[t.id];
      if (e == null || e.value.isEmpty) continue;
      logged++;
      final p = progress(t, e.value, sameDay: entries);
      earned += p;
      if (isComplete(p)) done++;
    }
    return DaySummary(
      day: day,
      expected: expected,
      earned: earned,
      done: done,
      logged: logged,
    );
  }
}

class DaySummary {
  const DaySummary({
    required this.day,
    required this.expected,
    required this.earned,
    required this.done,
    required this.logged,
  });

  final Day day;

  /// Required trackers expected that day.
  final int expected;

  /// Sum of credit earned.
  final double earned;

  /// Trackers whose goal was fully met.
  final int done;
  final int logged;

  bool get isRestDay => expected == 0;

  double get score => expected == 0 ? 0 : (earned / expected).clamp(0, 1);

  bool get isPerfect => !isRestDay && Scoring.isComplete(score);

  bool isWin(double threshold) => !isRestDay && score >= threshold - 1e-9;
}
