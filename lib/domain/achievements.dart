import 'package:flutter/foundation.dart';

import '../core/time/day.dart';
import 'analytics.dart';
import 'models.dart';
import 'scoring.dart';
import 'tracker_goal.dart';
import 'tracker_type.dart';
import 'tracker_value.dart';

enum AchievementKind {
  perfect('Perfect day'),
  streak('Streak milestone'),
  congregation('Every prayer in congregation'),
  onTime('Every prayer on time'),
  meals('Every meal on time'),
  badge('');

  const AchievementKind(this.legend);

  /// How the grid's legend names it (badges use their trackers' names).
  final String legend;
}

/// Something earned on a day, shown as a tiny emoji on the journey grid.
@immutable
class Achievement {
  const Achievement(
    this.emoji,
    this.label, {
    this.kind = AchievementKind.badge,
    this.coveredByPerfect = false,
  });

  final String emoji;
  final String label;
  final AchievementKind kind;

  /// A perfect day already says this (every goal met), so its tile can
  /// leave it out. Never true for congregation: on time scores 100% too.
  final bool coveredByPerfect;

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
  static const perfect = Achievement(
    '🌟',
    'Perfect day',
    kind: AchievementKind.perfect,
  );
  static const congregationEmoji = '🕌';
  static const onTimeEmoji = '🤲';
  static const streakEmoji = '🔥';
  static const mealsEmoji = '🍽️';

  /// The grid's own emojis; a tracker can't use them (they'd be misread).
  static const reserved = {
    '🌟',
    streakEmoji,
    congregationEmoji,
    onTimeEmoji,
    mealsEmoji,
  };

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

  /// A prayer: it has the prayer options ("On time", with "Late",
  /// "Missed" or "In congregation"), whatever it's called.
  static bool isPrayer(Tracker t) =>
      t.type == TrackerType.singleChoice &&
      t.config.optionById('ontime') != null &&
      (t.config.optionById('jamaah') != null ||
          t.config.optionById('late') != null ||
          t.config.optionById('missed') != null);

  /// A meal's "… on time?" check, also when renamed (On time / Late).
  static bool isMealCheck(Tracker t) =>
      t.type == TrackerType.checkbox &&
      t.goal is BoolGoal &&
      t.winAnswer &&
      (t.name.toLowerCase().trimRight().endsWith('on time?') ||
          (t.config.yesLabel == 'On time' && t.config.noLabel == 'Late'));

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
      if (streak != null)
        Achievement(
          streakEmoji,
          '$streak-day streak',
          kind: AchievementKind.streak,
        ),
    ];

    final prayers = [
      for (final t in active)
        if (isPrayer(t) && t.isExpectedOn(day, sameDay: sameDay)) t,
    ];
    if (prayers.isNotEmpty) {
      bool onTime(Tracker p) =>
          complete(p) || const {'jamaah', 'ontime'}.contains(optionOf(p));
      // No masjid (e.g. at the office, or a prayer without the option):
      // on time counts as congregation.
      bool noMasjid(Tracker p) =>
          p.config.optionById('jamaah') == null ||
          (p.ruleOn(sameDay)?.hideOptionIds.contains('jamaah') ?? false);
      bool inCongregation(Tracker p) =>
          optionOf(p) == 'jamaah' || (optionOf(p) == 'ontime' && noMasjid(p));
      final all = prayers.length == 1
          ? prayers.single.name
          : 'All ${prayers.length} prayers';
      if (prayers.every(inCongregation)) {
        final alone = prayers.any((p) => optionOf(p) == 'ontime');
        list.add(
          Achievement(
            congregationEmoji,
            alone
                ? '$all in congregation (on time where there was no masjid)'
                : '$all in congregation',
            kind: AchievementKind.congregation,
          ),
        );
      } else if (prayers.every(onTime)) {
        list.add(
          Achievement(
            onTimeEmoji,
            '$all on time',
            kind: AchievementKind.onTime,
            coveredByPerfect: prayers.every((p) => p.isRequired),
          ),
        );
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
          kind: AchievementKind.meals,
          coveredByPerfect: meals.every((t) => t.isRequired),
        ),
      );
    }

    for (final t in active) {
      final badge = badgeOf(t);
      if (badge.isNotEmpty && complete(t)) {
        list.add(
          Achievement(
            badge,
            t.name,
            coveredByPerfect:
                t.isRequired && t.isExpectedOn(day, sameDay: sameDay),
          ),
        );
      }
    }
    return list;
  }

  /// What a grid tile shows, at most [max]. On a perfect day the star
  /// stands for every goal met, so only what it doesn't say stays: a
  /// streak, congregation, optional trackers.
  static List<Achievement> shownOnTile(List<Achievement> day, {int max = 3}) {
    final perfectDay = day.any((a) => a.kind == AchievementKind.perfect);
    return [
      for (final a in day)
        if (!perfectDay || !a.coveredByPerfect) a,
    ].take(max).toList();
  }

  /// The emojis of [shownOnTile].
  static List<String> cellEmojis(List<Achievement> day, {int max = 3}) => [
    for (final a in shownOnTile(day, max: max)) a.emoji,
  ];
}
