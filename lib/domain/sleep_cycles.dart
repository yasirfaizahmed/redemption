import 'package:flutter/foundation.dart';

import '../core/time/day.dart';

/// One suggested wake-up time: the end of a full sleep cycle.
@immutable
class WakeTime {
  const WakeTime({required this.cycles, required this.at});

  /// Full ~90-minute cycles slept by then.
  final int cycles;

  /// Local wall-clock time to wake up.
  final DateTime at;

  /// Time asleep (not counting the time it takes to fall asleep).
  int get sleepMinutes => cycles * SleepCycles.cycleMinutes;

  /// 5–6 cycles (7½–9 h) fit the 7–9 hours adults need.
  bool get isRecommended => cycles == 5 || cycles == 6;

  @override
  bool operator ==(Object other) =>
      other is WakeTime && other.cycles == cycles && other.at == at;

  @override
  int get hashCode => Object.hash(cycles, at);
}

/// Sleep runs in cycles of about 90 minutes. Waking at the end of one —
/// in light sleep — feels fresher than being pulled out of deep sleep.
abstract final class SleepCycles {
  static const cycleMinutes = 90;
  static const maxCycles = 6;

  /// Choices offered for the time it takes to fall asleep.
  static const fallAsleepChoices = [0, 10, 15, 20, 30];

  /// When a bedtime at [minutes] past midnight happens for the logical
  /// [day]: on its date, or the next one before the day starts (00:30
  /// belongs to the night of the day before when days start at 03:00).
  static DateTime bedtimeOn(
    Day day,
    int minutes, {
    required int dayStartMinutes,
  }) => DateTime(
    day.year,
    day.month,
    day.day + (minutes < dayStartMinutes ? 1 : 0),
    minutes ~/ 60,
    minutes % 60,
  );

  /// Wake-up times after 1…[maxCycles] full cycles, counted from
  /// [bedtime] plus [fallAsleepMinutes]. Durations are real time, so a
  /// clock change during the night is taken into account.
  static List<WakeTime> wakeTimes(
    DateTime bedtime, {
    int fallAsleepMinutes = 0,
    int maxCycles = SleepCycles.maxCycles,
  }) {
    final asleep = bedtime.add(Duration(minutes: fallAsleepMinutes));
    return [
      for (var n = 1; n <= maxCycles; n++)
        WakeTime(
          cycles: n,
          at: asleep.add(Duration(minutes: n * cycleMinutes)),
        ),
    ];
  }
}
