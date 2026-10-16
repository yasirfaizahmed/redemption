import 'dart:math' as math;

import '../core/time/day.dart';
import '../core/time/time_of_day_x.dart';
import 'models.dart';
import 'neuro_phase.dart';
import 'scoring.dart';
import 'tracker_type.dart';
import 'tracker_value.dart';

/// Aggregate statistics of a journey up to "today".
class JourneyStats {
  JourneyStats._({
    required this.journey,
    required this.today,
    required this.days,
    required this.summaryByDay,
    required this.currentStreak,
    required this.bestStreak,
    required this.winDays,
    required this.perfectDays,
    required this.countedDays,
    required this.averageScore,
  });

  factory JourneyStats.compute({
    required Journey journey,
    required List<Tracker> trackers,
    required EntryIndex index,
    required Day today,
    required Scoring scoring,
    required double threshold,
  }) {
    final last = today.isBefore(journey.endDay) ? today : journey.endDay;
    final days = <DaySummary>[];
    if (!today.isBefore(journey.startDay)) {
      for (final d in Day.range(journey.startDay, last)) {
        days.add(scoring.summarize(d, trackers, index));
      }
    }

    var run = 0;
    var best = 0;
    var wins = 0;
    var perfect = 0;
    var counted = 0;
    var scoreSum = 0.0;
    for (final s in days) {
      if (s.isRestDay) continue;
      final isToday = s.day == today;
      final win = s.isWin(threshold);
      // An unfinished "today" never breaks a streak or drags averages down.
      if (isToday && !win) continue;
      counted++;
      scoreSum += s.score;
      if (s.isPerfect) perfect++;
      if (win) {
        wins++;
        run++;
        best = math.max(best, run);
      } else {
        run = 0;
      }
    }

    return JourneyStats._(
      journey: journey,
      today: today,
      days: days,
      summaryByDay: {for (final s in days) s.day: s},
      currentStreak: run,
      bestStreak: best,
      winDays: wins,
      perfectDays: perfect,
      countedDays: counted,
      averageScore: counted == 0 ? 0 : scoreSum / counted,
    );
  }

  final Journey journey;
  final Day today;

  /// Summaries from the start day up to min(today, end day).
  final List<DaySummary> days;
  final Map<Day, DaySummary> summaryByDay;
  final int currentStreak;
  final int bestStreak;
  final int winDays;
  final int perfectDays;

  /// Days that count towards averages (excludes rest days and an unfinished today).
  final int countedDays;
  final double averageScore;

  bool get hasStarted => !today.isBefore(journey.startDay);
  bool get isFinished => today.isAfter(journey.endDay);

  /// 1-based current day number clamped to the journey length (0 if not started).
  int get dayNumber =>
      journey.dayNumber(today).clamp(0, journey.durationDays).toInt();

  int get daysLeft => math.max(0, journey.durationDays - dayNumber);

  double get elapsedFraction =>
      journey.durationDays == 0 ? 0 : dayNumber / journey.durationDays;

  double get consistency => countedDays == 0 ? 0 : winDays / countedDays;

  DaySummary? get todaySummary => summaryByDay[today];

  NeuroPhase get phase => NeuroPhase.forDay(
    dayNumber: math.max(1, dayNumber),
    totalDays: journey.durationDays,
  );
}

/// Statistics for one tracker within a journey.
class TrackerStats {
  TrackerStats._({
    required this.tracker,
    required this.expectedDays,
    required this.doneDays,
    required this.loggedDays,
    required this.plannedDays,
    required this.currentStreak,
    required this.bestStreak,
    required this.average,
    required this.total,
    required this.lastEntry,
    required this.optionCounts,
  });

  factory TrackerStats.compute({
    required Tracker tracker,
    required Journey journey,
    required EntryIndex index,
    required Day today,
    required Scoring scoring,
  }) {
    final entries = index.forTracker(tracker.id);
    var planned = 0;
    // Days a skip rule switched off (e.g. work from home) aren't planned;
    // future days have no answers yet, so they all count as planned.
    for (final d in Day.range(journey.startDay, journey.endDay)) {
      if (tracker.isExpectedOn(d, sameDay: index.forDay(d))) planned++;
    }

    var expected = 0;
    var done = 0;
    var run = 0;
    var best = 0;
    final last = today.isBefore(journey.endDay) ? today : journey.endDay;
    if (!today.isBefore(journey.startDay)) {
      for (final d in Day.range(journey.startDay, last)) {
        final sameDay = index.forDay(d);
        if (!tracker.isExpectedOn(d, sameDay: sameDay)) continue;
        final e = entries[d];
        final p = scoring.progress(tracker, e?.value, sameDay: sameDay);
        final complete = Scoring.isComplete(p);
        if (d == today && !complete) continue; // today still in progress
        expected++;
        if (complete) {
          done++;
          run++;
          best = math.max(best, run);
        } else {
          run = 0;
        }
      }
    }

    // Numeric aggregates & choice distribution over every logged entry.
    final numbers = <double>[];
    final optionCounts = <String, int>{};
    Entry? lastEntry;
    for (final e in entries.values) {
      if (e.value.isEmpty) continue;
      if (lastEntry == null || e.day.isAfter(lastEntry.day)) lastEntry = e;
      final v = e.value;
      if (v is ChoiceValue) {
        optionCounts[v.optionId] = (optionCounts[v.optionId] ?? 0) + 1;
      } else if (v is MultiChoiceValue) {
        for (final id in v.optionIds) {
          optionCounts[id] = (optionCounts[id] ?? 0) + 1;
        }
      } else if (v is BoolValue) {
        final key = v.value ? 'yes' : 'no';
        optionCounts[key] = (optionCounts[key] ?? 0) + 1;
      }
      if (tracker.type.isChartable) {
        final n = scoring.numericValue(tracker, v);
        if (n != null) numbers.add(n);
      }
    }
    double? average;
    double? total;
    if (numbers.isNotEmpty) {
      total = numbers.fold<double>(0, (a, b) => a + b);
      average = total / numbers.length;
      if (tracker.type == TrackerType.time) {
        // Averaged on the day-relative axis, converted back to a clock time.
        average = Clock.fromRelative(
          average.round(),
          scoring.dayStartMinutes,
        ).toDouble();
        total = null;
      }
    }

    return TrackerStats._(
      tracker: tracker,
      expectedDays: expected,
      doneDays: done,
      loggedDays: entries.values.where((e) => !e.value.isEmpty).length,
      plannedDays: planned,
      currentStreak: run,
      bestStreak: best,
      average: average,
      total: total,
      lastEntry: lastEntry,
      optionCounts: optionCounts,
    );
  }

  final Tracker tracker;

  /// Elapsed days this tracker was expected (today only once completed).
  final int expectedDays;
  final int doneDays;
  final int loggedDays;

  /// Days this tracker is expected across the whole journey.
  final int plannedDays;
  final int currentStreak;
  final int bestStreak;

  /// Mean numeric value. For time trackers: minutes since midnight.
  final double? average;
  final double? total;
  final Entry? lastEntry;
  final Map<String, int> optionCounts;

  double get successRate => expectedDays == 0 ? 0 : doneDays / expectedDays;

  /// Progress towards hitting the goal on every planned day of the journey.
  double get journeyProgress => plannedDays == 0 ? 0 : doneDays / plannedDays;
}

class SeriesPoint {
  const SeriesPoint(this.day, this.value, this.progress);
  final Day day;

  /// Chartable value (null when nothing was logged).
  final double? value;
  final double progress;
}

/// Chart-ready series of [tracker] over [from]..[to].
List<SeriesPoint> buildSeries({
  required Tracker tracker,
  required EntryIndex index,
  required Scoring scoring,
  required Day from,
  required Day to,
}) {
  final entries = index.forTracker(tracker.id);
  return [
    for (final d in Day.range(from, to))
      () {
        final e = entries[d];
        if (e == null || e.value.isEmpty) return SeriesPoint(d, null, 0);
        final n = tracker.type.isChartable
            ? scoring.numericValue(tracker, e.value)
            : null;
        final p = scoring.progress(tracker, e.value, sameDay: index.forDay(d));
        return SeriesPoint(d, n ?? p * 100, p);
      }(),
  ];
}

/// Frequently used comma/line separated items from a text tracker's history,
/// most frequent first. Powers the tap-to-add suggestion chips.
List<String> textSuggestions(
  Tracker tracker,
  EntryIndex index, {
  int limit = 12,
}) {
  final counts = <String, int>{};
  final display = <String, String>{};
  final lastSeen = <String, Day>{};
  for (final e in index.forTracker(tracker.id).values) {
    final v = e.value;
    if (v is! TextValue) continue;
    for (final raw in v.text.split(RegExp(r'[,\n;•]'))) {
      final item = raw.trim();
      if (item.isEmpty || item.length > 40) continue;
      final key = item.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
      final seen = lastSeen[key];
      if (seen == null || !e.day.isBefore(seen)) {
        lastSeen[key] = e.day;
        display[key] = item;
      }
    }
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      return c != 0 ? c : lastSeen[b]!.compareTo(lastSeen[a]!);
    });
  return [for (final k in keys.take(limit)) display[k]!];
}
