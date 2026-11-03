import 'package:flutter/foundation.dart';

import '../core/time/day.dart';
import 'analytics.dart';
import 'models.dart';
import 'scoring.dart';
import 'tracker_type.dart';
import 'tracker_value.dart';

/// Something earned on a day, shown as a tiny emoji on the journey grid.
@immutable
class Achievement {
  const Achievement(this.emoji, this.label);

  final String emoji;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is Achievement && other.emoji == emoji && other.label == label;

  @override
  int get hashCode => Object.hash(emoji, label);

  @override
  String toString() => '$emoji $label';
}

/// What each day of a journey earned, most notable first:
///
/// - 🌟 a perfect day (every goal met),
/// - 🔥 a win streak reaching a milestone (3, 7, 14, 21, 30, 40… days),
/// - 🕌 every prayer in congregation (🤲 every prayer on time),
/// - 🍽️ every meal on time,
/// - a tracker's own emoji (💪 Workout, 🌅 Wake-up time…) when its goal
///   is fully met — set per tracker in the editor.
abstract final class Achievements {
  static const perfect = Achievement('🌟', 'Perfect day');
  static const congregationEmoji = '🕌';
  static const onTimeEmoji = '🤲';
  static const streakEmoji = '🔥';
  static const mealsEmoji = '🍽️';

  /// Win-streak lengths worth celebrating; after 90, every 30 days.
  static const streakMilestones = {3, 7, 14, 21, 30, 40, 50, 60, 66, 75, 90};

  static bool isMilestone(int streak) =>
      streakMilestones.contains(streak) || (streak > 90 && streak % 30 == 0);

  /// A tracker's emoji when the user hasn't chosen one, by template name.
  static const defaultBadges = {
    'Wake-up time': '🌅',
    'Workout': '💪',
    'Training': '💪',
    'Sleep time': '🌙',
    'Sleep': '😴',
    'Water': '💧',
    'Steps': '👣',
    'Reading': '📖',
    'Deep work': '🎯',
    'Social-media free': '📵',
    'Journal': '✍️',
    'Stayed clean today': '🛡️',
  };

  /// The emoji [tracker] earns on days its goal is met ('' for none).
  static String badgeOf(Tracker tracker) =>
      tracker.config.badge ?? defaultBadges[tracker.name] ?? '';

  /// A prayer: the prayer options with congregation and on time.
  static bool isPrayer(Tracker t) =>
      t.type == TrackerType.singleChoice &&
      t.config.optionById('jamaah') != null &&
      t.config.optionById('ontime') != null;

  /// A meal's "… on time?" check.
  static bool isMealCheck(Tracker t) =>
      t.type == TrackerType.checkbox &&
      t.name.toLowerCase().trimRight().endsWith('on time?');

  /// The achievements of every day of [stats] (journey start to today).
  static Map<Day, List<Achievement>> forJourney({
    required JourneyStats stats,
    required List<Tracker> trackers,
    required EntryIndex index,
    required Scoring scoring,
    required double threshold,
  }) {
    final result = <Day, List<Achievement>>{};
    var run = 0;
    for (final s in stats.days) {
      int? milestone;
      // The same streak rules as the journey stats: rest days don't break
      // it, and an unfinished today doesn't either.
      if (!s.isRestDay && !(s.day == stats.today && !s.isWin(threshold))) {
        if (s.isWin(threshold)) {
          run++;
          if (isMilestone(run)) milestone = run;
        } else {
          run = 0;
        }
      }
      final list = forDay(
        s.day,
        summary: s,
        trackers: trackers,
        sameDay: index.forDay(s.day),
        scoring: scoring,
        streak: milestone,
      );
      if (list.isNotEmpty) result[s.day] = list;
    }
    return result;
  }

  /// What [day] earned. [streak] is a milestone the win streak reached
  /// that day, if any.
  static List<Achievement> forDay(
    Day day, {
    required DaySummary summary,
    required List<Tracker> trackers,
    required Map<int, Entry> sameDay,
    required Scoring scoring,
    int? streak,
  }) {
    final active = [
      for (final t in trackers)
        if (t.isActiveOn(day)) t,
    ];
    bool logged(Tracker t) => !(sameDay[t.id]?.value.isEmpty ?? true);
    bool complete(Tracker t) =>
        logged(t) &&
        Scoring.isComplete(
          scoring.progress(t, sameDay[t.id]!.value, sameDay: sameDay),
        );
    String? optionOf(Tracker t) => switch (sameDay[t.id]?.value) {
      ChoiceValue(:final optionId) => optionId,
      _ => null,
    };

    final list = <Achievement>[
      if (summary.isPerfect) perfect,
      if (streak != null) Achievement(streakEmoji, '$streak-day streak'),
    ];

    final prayers = [
      for (final t in active)
        if (isPrayer(t) && t.isExpectedOn(day, sameDay: sameDay)) t,
    ];
    if (prayers.isNotEmpty) {
      bool onTime(Tracker p) =>
          complete(p) || const {'jamaah', 'ontime'}.contains(optionOf(p));
      // No masjid that day (e.g. at the office): on time counts as
      // congregation.
      bool inCongregation(Tracker p) =>
          optionOf(p) == 'jamaah' ||
          (optionOf(p) == 'ontime' &&
              (p.ruleOn(sameDay)?.hideOptionIds.contains('jamaah') ?? false));
      final all = prayers.length == 1
          ? prayers.single.name
          : 'All ${prayers.length} prayers';
      if (prayers.every(inCongregation)) {
        list.add(Achievement(congregationEmoji, '$all in congregation'));
      } else if (prayers.every(onTime)) {
        list.add(Achievement(onTimeEmoji, '$all on time'));
      }
    }

    final meals = [
      for (final t in active)
        if (isMealCheck(t) && t.isExpectedOn(day, sameDay: sameDay)) t,
    ];
    if (meals.isNotEmpty && meals.every(complete)) {
      list.add(
        Achievement(
          mealsEmoji,
          meals.length == 1 ? meals.single.name : 'Every meal on time',
        ),
      );
    }

    for (final t in active) {
      final badge = badgeOf(t);
      if (badge.isNotEmpty && complete(t)) list.add(Achievement(badge, t.name));
    }
    return list;
  }

  /// The emojis to draw in a grid cell, at most [max]. A perfect day met
  /// every goal, so its own star (and a streak) says it all.
  static List<String> cellEmojis(List<Achievement> day, {int max = 3}) {
    final shown = day.contains(perfect)
        ? [
            for (final a in day)
              if (a == perfect || a.emoji == streakEmoji) a,
          ]
        : day;
    return [for (final a in shown.take(max)) a.emoji];
  }
}
