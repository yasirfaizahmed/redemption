import 'package:collection/collection.dart';

import '../core/time/day.dart';
import 'models.dart';
import 'templates.dart';
import 'tracker_type.dart';

/// Improvements made to the Redemption template after v1.0.0 that an
/// existing journey can opt into, without touching its scores.
///
/// Each part has its own id, so declining or applying one never hides a
/// part added in a later version.
class JourneyUpgrade {
  const JourneyUpgrade({
    this.workMode,
    this.prayers = const [],
    this.meals = const [],
    this.workout,
    this.mealTexts = const [],
  });

  /// Office-day prayers + meal on-time checks (v1.1.0).
  static const officeAndMealsId = 'office-day-prayers-and-meal-times';

  /// Workout as Yes/No with a comment (v1.2.0).
  static const workoutId = 'workout-yes-no';

  /// Meal text entries folded into the on-time checks as info (v1.3.0).
  static const mealCommentsId = 'meal-comments';

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

  /// A text "Workout" tracker to turn into "Did you train?" + comment.
  final Tracker? workout;

  /// Text meal trackers ("what I ate") whose entries move into the matching
  /// "… on time?" check as information; they are archived from today,
  /// so only eating on time earns points.
  final List<Tracker> mealTexts;

  bool get hasOfficeAndMeals => prayers.isNotEmpty || meals.isNotEmpty;
  bool get isEmpty =>
      !hasOfficeAndMeals && workout == null && mealTexts.isEmpty;

  /// Ids of the parts this upgrade contains.
  Set<String> get ids => {
    if (hasOfficeAndMeals) officeAndMealsId,
    if (workout != null) workoutId,
    if (mealTexts.isNotEmpty) mealCommentsId,
  };

  /// Name of the on-time check a meal text tracker folds into.
  static String checkNameFor(Tracker mealText) =>
      '${mealNames[mealText.name] ?? mealText.name} on time?';

  /// What applying the upgrade would change in a journey's [trackers]
  /// (archived ones included), leaving out [dismissed] parts.
  static JourneyUpgrade plan(
    List<Tracker> trackers, {
    Set<String> dismissed = const {},
  }) {
    final active = [
      for (final t in trackers)
        if (!t.isArchived) t,
    ];

    // Office days & meals: only for journeys with none of the additions
    // (they came from the v1.1+ template, or were upgraded) — removing one
    // later doesn't bring the offer back.
    final hasAdditions = trackers.any(
      (t) =>
          (officePrayers.contains(t.name) && t.config.dayRule != null) ||
          mealNames.values.any((m) => t.name == '$m on time?'),
    );
    Tracker? workMode;
    var prayers = const <Tracker>[];
    var meals = const <(Tracker, String)>[];
    if (!hasAdditions && !dismissed.contains(officeAndMealsId)) {
      workMode = active.firstWhereOrNull(
        (t) =>
            t.type == TrackerType.singleChoice &&
            t.config.optionById('office') != null,
      );
      prayers = workMode == null
          ? const []
          : [
              for (final t in active)
                if (officePrayers.contains(t.name) &&
                    t.type == TrackerType.singleChoice &&
                    t.config.optionById('ontime') != null &&
                    t.config.dayRule == null)
                  t,
            ];
      final seen = <String>{};
      meals = [
        for (final t in active)
          if (mealNames[t.name] case final name? when seen.add(name)) (t, name),
      ];
    }

    final workout = dismissed.contains(workoutId)
        ? null
        : active.firstWhereOrNull(
            (t) =>
                t.name == 'Workout' &&
                (t.type == TrackerType.longText || t.type == TrackerType.text),
          );

    final mealTexts = dismissed.contains(mealCommentsId)
        ? const <Tracker>[]
        : [
            for (final t in active)
              if (mealNames.containsKey(t.name) &&
                  (t.type == TrackerType.longText ||
                      t.type == TrackerType.text))
                t,
          ];

    return JourneyUpgrade(
      workMode: workMode,
      prayers: prayers,
      meals: meals,
      workout: workout,
      mealTexts: mealTexts,
    );
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

  /// [workout] as "Did you train?" (win = Trained) asking for a comment.
  /// Keeps its id, schedule, reminders and history.
  Tracker? workoutAsYesNo() => workout?.copyWith(
    type: TrackerType.checkbox,
    goal: workoutTracker(at: 0).goal,
    // A description the user wrote stays; the old template default goes.
    description: switch (workout!.description.trim()) {
      '' || 'What did you train?' => workoutTracker(at: 0).description,
      final own => own,
    },
    config: workoutConfig.copyWith(
      placeholder: workout!.config.placeholder.isEmpty
          ? workoutConfig.placeholder
          : workout!.config.placeholder,
    ),
  );
}
