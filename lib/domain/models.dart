import 'package:flutter/foundation.dart';

import '../core/time/day.dart';
import 'tracker_config.dart';
import 'tracker_goal.dart';
import 'tracker_type.dart';
import 'tracker_value.dart';

/// A time-boxed challenge, e.g. "90 days of Redemption".
@immutable
class Journey {
  const Journey({
    required this.id,
    required this.name,
    required this.intention,
    required this.startDay,
    required this.durationDays,
    required this.isActive,
    required this.createdAt,
  });

  final int id;
  final String name;

  /// The user's "why" (niyyah). Shown on the dashboard as a reminder.
  final String intention;
  final Day startDay;
  final int durationDays;
  final bool isActive;
  final DateTime createdAt;

  Day get endDay => startDay.addDays(durationDays - 1);

  /// 1-based index of [day] within the journey (may be ≤0 or >duration).
  int dayNumber(Day day) => day.difference(startDay) + 1;

  bool contains(Day day) =>
      day.isSameOrAfter(startDay) && day.isSameOrBefore(endDay);

  Journey copyWith({
    String? name,
    String? intention,
    Day? startDay,
    int? durationDays,
    bool? isActive,
  }) => Journey(
    id: id,
    name: name ?? this.name,
    intention: intention ?? this.intention,
    startDay: startDay ?? this.startDay,
    durationDays: durationDays ?? this.durationDays,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
  );
}

/// Bit mask of ISO weekdays: bit 0 = Monday … bit 6 = Sunday.
abstract final class Weekdays {
  static const all = 0x7F;
  static const workweek = 0x1F; // Mon–Fri
  static const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static bool has(int mask, int isoWeekday) =>
      mask & (1 << (isoWeekday - 1)) != 0;

  static int toggle(int mask, int isoWeekday) => mask ^ (1 << (isoWeekday - 1));

  static String describe(int mask) {
    if (mask == all) return 'Every day';
    if (mask == workweek) return 'Weekdays';
    if (mask == 0x60) return 'Weekends';
    if (mask == 0) return 'Never';
    return [
      for (var d = 1; d <= 7; d++)
        if (has(mask, d)) names[d - 1],
    ].join(', ');
  }
}

/// Definition of something tracked every day.
@immutable
class Tracker {
  const Tracker({
    required this.id,
    required this.journeyId,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.activeFrom,
    this.description = '',
    this.section = '',
    this.anchorMinutes,
    this.weekdays = Weekdays.all,
    this.isRequired = true,
    this.config = const TrackerConfig(),
    this.goal = const LoggedGoal(),
    this.reminderEnabled = false,
    this.reminderMinutes,
    this.sortOrder = 0,
    this.archivedOn,
  });

  final int id;
  final int journeyId;
  final String name;
  final String description;
  final TrackerType type;

  /// Key into the curated icon catalogue (see `TrackerIcons`).
  final String icon;

  /// ARGB colour value.
  final int color;

  /// Free-form grouping such as "Morning" or "Salah".
  final String section;

  /// Planned time of day (minutes since midnight). Drives the timeline.
  final int? anchorMinutes;
  final int weekdays;

  /// Whether this tracker counts towards the daily score.
  final bool isRequired;
  final TrackerConfig config;
  final TrackerGoal goal;
  final bool reminderEnabled;
  final int? reminderMinutes;
  final int sortOrder;

  /// First day this tracker is expected (it never counts against earlier days).
  final Day activeFrom;

  /// When archived, the tracker stops counting from this day onwards.
  final Day? archivedOn;

  bool get isArchived => archivedOn != null;

  bool isScheduledOn(Day day) => Weekdays.has(weekdays, day.weekday);

  bool isActiveOn(Day day) =>
      day.isSameOrAfter(activeFrom) &&
      (archivedOn == null || day.isBefore(archivedOn!));

  /// Expected on [day] (active and scheduled).
  bool isExpectedOn(Day day) => isActiveOn(day) && isScheduledOn(day);

  /// Expected on [day] and counts towards the daily score.
  bool countsOn(Day day) => isRequired && isExpectedOn(day);

  Tracker copyWith({
    int? id,
    int? journeyId,
    String? name,
    String? description,
    TrackerType? type,
    String? icon,
    int? color,
    String? section,
    int? Function()? anchorMinutes,
    int? weekdays,
    bool? isRequired,
    TrackerConfig? config,
    TrackerGoal? goal,
    bool? reminderEnabled,
    int? Function()? reminderMinutes,
    int? sortOrder,
    Day? activeFrom,
    Day? Function()? archivedOn,
  }) => Tracker(
    id: id ?? this.id,
    journeyId: journeyId ?? this.journeyId,
    name: name ?? this.name,
    description: description ?? this.description,
    type: type ?? this.type,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    section: section ?? this.section,
    anchorMinutes: anchorMinutes != null ? anchorMinutes() : this.anchorMinutes,
    weekdays: weekdays ?? this.weekdays,
    isRequired: isRequired ?? this.isRequired,
    config: config ?? this.config,
    goal: goal ?? this.goal,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderMinutes: reminderMinutes != null
        ? reminderMinutes()
        : this.reminderMinutes,
    sortOrder: sortOrder ?? this.sortOrder,
    activeFrom: activeFrom ?? this.activeFrom,
    archivedOn: archivedOn != null ? archivedOn() : this.archivedOn,
  );
}

/// One logged value of a tracker on a day. At most one per tracker per day.
@immutable
class Entry {
  const Entry({
    required this.id,
    required this.trackerId,
    required this.day,
    required this.value,
    this.note = '',
    required this.updatedAt,
  });

  final int id;
  final int trackerId;
  final Day day;
  final TrackerValue value;
  final String note;
  final DateTime updatedAt;
}

/// Fast lookup of entries by day and tracker.
class EntryIndex {
  EntryIndex(Iterable<Entry> entries) {
    for (final e in entries) {
      (_byDay[e.day] ??= {})[e.trackerId] = e;
      (_byTracker[e.trackerId] ??= {})[e.day] = e;
    }
  }

  static final empty = EntryIndex(const []);

  final Map<Day, Map<int, Entry>> _byDay = {};
  final Map<int, Map<Day, Entry>> _byTracker = {};

  Entry? get(int trackerId, Day day) => _byDay[day]?[trackerId];

  Map<int, Entry> forDay(Day day) => _byDay[day] ?? const {};

  Map<Day, Entry> forTracker(int trackerId) =>
      _byTracker[trackerId] ?? const {};

  int get length => _byDay.values.fold(0, (sum, m) => sum + m.length);
}
