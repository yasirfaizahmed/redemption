import 'package:flutter/foundation.dart';

enum NumberComparator { atLeast, atMost, between }

enum TimeComparator { before, after }

/// What counts as "success" for a tracker on a given day.
/// Serialised as `{"kind": …}`.
@immutable
sealed class TrackerGoal {
  const TrackerGoal();

  static TrackerGoal fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LoggedGoal();
    return switch (json['kind']) {
      'bool' => BoolGoal(target: json['target'] as bool? ?? true),
      'number' => NumberGoal(
        comparator: NumberComparator.values.firstWhere(
          (c) => c.name == json['op'],
          orElse: () => NumberComparator.atLeast,
        ),
        value: (json['value'] as num).toDouble(),
        upper: (json['upper'] as num?)?.toDouble(),
      ),
      'time' => TimeGoal(
        comparator: TimeComparator.values.firstWhere(
          (c) => c.name == json['op'],
          orElse: () => TimeComparator.before,
        ),
        minutes: json['minutes'] as int,
        graceMinutes: json['grace'] as int? ?? 0,
      ),
      'choice' => const ChoiceScoreGoal(),
      _ => const LoggedGoal(),
    };
  }

  Map<String, dynamic> toJson();
}

/// Success as soon as anything is logged.
final class LoggedGoal extends TrackerGoal {
  const LoggedGoal();
  @override
  Map<String, dynamic> toJson() => {'kind': 'logged'};
  @override
  bool operator ==(Object other) => other is LoggedGoal;
  @override
  int get hashCode => 0;
}

/// Success when the answer matches [target]. `target: false` models habits
/// you are quitting ("Stayed away from X?" → No is the win).
final class BoolGoal extends TrackerGoal {
  const BoolGoal({this.target = true});
  final bool target;
  @override
  Map<String, dynamic> toJson() => {'kind': 'bool', 'target': target};
  @override
  bool operator ==(Object other) => other is BoolGoal && other.target == target;
  @override
  int get hashCode => target.hashCode;
}

/// Numeric target. `atLeast` earns partial credit (5 of 8 glasses = 62%).
final class NumberGoal extends TrackerGoal {
  const NumberGoal({required this.comparator, required this.value, this.upper});
  final NumberComparator comparator;
  final double value;

  /// Upper bound for [NumberComparator.between].
  final double? upper;

  @override
  Map<String, dynamic> toJson() => {
    'kind': 'number',
    'op': comparator.name,
    'value': value,
    'upper': ?upper,
  };
  @override
  bool operator ==(Object other) =>
      other is NumberGoal &&
      other.comparator == comparator &&
      other.value == value &&
      other.upper == upper;
  @override
  int get hashCode => Object.hash(comparator, value, upper);
}

/// Clock-time target, e.g. "wake before 05:00". Late within [graceMinutes]
/// earns half credit.
final class TimeGoal extends TrackerGoal {
  const TimeGoal({
    required this.comparator,
    required this.minutes,
    this.graceMinutes = 0,
  });
  final TimeComparator comparator;
  final int minutes;
  final int graceMinutes;

  @override
  Map<String, dynamic> toJson() => {
    'kind': 'time',
    'op': comparator.name,
    'minutes': minutes,
    'grace': graceMinutes,
  };
  @override
  bool operator ==(Object other) =>
      other is TimeGoal &&
      other.comparator == comparator &&
      other.minutes == minutes &&
      other.graceMinutes == graceMinutes;
  @override
  int get hashCode => Object.hash(comparator, minutes, graceMinutes);
}

/// The picked option's own score is the credit earned.
final class ChoiceScoreGoal extends TrackerGoal {
  const ChoiceScoreGoal();
  @override
  Map<String, dynamic> toJson() => {'kind': 'choice'};
  @override
  bool operator ==(Object other) => other is ChoiceScoreGoal;
  @override
  int get hashCode => 1;
}
