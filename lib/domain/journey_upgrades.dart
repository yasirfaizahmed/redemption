import 'package:collection/collection.dart';

import '../core/time/day.dart';
import 'models.dart';
import 'templates.dart';
import 'tracker_type.dart';

/// Improvements made to the Redemption template after v1.0.0 that an
/// existing journey can opt into, without touching its history.
class JourneyUpgrade {
  const JourneyUpgrade({
    required this.workMode,
    required this.prayers,
    required this.meals,
  });

  static const id = 'office-day-prayers-and-meal-times';

  /// Prayers checked against [workMode] on office days.
  static const officePrayers = {'Dhuhr', 'Asr', 'Maghrib'};

  /// Meal tracker name → short name of its "on time?" check.
  static const mealNames = {
    'Breakfast': 'Breakfast',
    'Lunch': 'Lunch',
    'Post-workout dinner': 'Dinner',
    'Dinner': 'Dinner',
  };

  /// The "WFH or office?"-style tracker (has an "office" option).
  final Tracker? workMode;

  /// Prayers that get the office-day rule.
  final List<Tracker> prayers;

  /// Meals that get an "on time?" check, with the check's meal name.
  final List<(Tracker meal, String name)> meals;

  bool get isEmpty => prayers.isEmpty && meals.isEmpty;

  /// What applying the upgrade would change in a journey's [trackers]
  /// (archived ones included). Empty when nothing applies, or when the
  /// journey already has any of the additions (it came from the v1.1+
  /// template, or was upgraded) — removing one later doesn't bring the
  /// offer back.
  static JourneyUpgrade plan(List<Tracker> trackers) {
    const none = JourneyUpgrade(workMode: null, prayers: [], meals: []);
    final hasAdditions = trackers.any(
      (t) =>
          (officePrayers.contains(t.name) && t.config.dayRule != null) ||
          mealNames.values.any((m) => t.name == '$m on time?'),
    );
    if (hasAdditions) return none;
    final active = [
      for (final t in trackers)
        if (!t.isArchived) t,
    ];
    final workMode = active.firstWhereOrNull(
      (t) =>
          t.type == TrackerType.singleChoice &&
          t.config.optionById('office') != null,
    );
    final prayers = workMode == null
        ? const <Tracker>[]
        : [
            for (final t in active)
              if (officePrayers.contains(t.name) &&
                  t.type == TrackerType.singleChoice &&
                  t.config.optionById('ontime') != null &&
                  t.config.dayRule == null)
                t,
          ];
    final seen = <String>{};
    final meals = [
      for (final t in active)
        if (mealNames[t.name] case final name? when seen.add(name)) (t, name),
    ];
    return JourneyUpgrade(workMode: workMode, prayers: prayers, meals: meals);
  }

  /// The "on time?" trackers to add, starting [from] (so no past day
  /// counts against them).
  List<Tracker> newMealChecks({required int journeyId, required Day from}) => [
    for (final (meal, name) in meals)
      mealOnTime(
        name,
        section: meal.section,
        at: meal.anchorMinutes ?? 12 * 60,
      ).copyWith(journeyId: journeyId, activeFrom: from),
  ];

  /// [prayers] with the office-day rule attached.
  List<Tracker> prayersWithRule() => [
    for (final p in prayers)
      p.copyWith(
        config: p.config.copyWith(
          dayRule: () => officeDayRule(whenTrackerId: workMode!.id),
        ),
      ),
  ];
}
