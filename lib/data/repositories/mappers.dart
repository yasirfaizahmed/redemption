import 'package:drift/drift.dart';

import '../../domain/dashboard.dart';
import '../../domain/models.dart';
import '../db/database.dart';

extension JourneyRowX on JourneyRow {
  Journey toDomain() => Journey(
    id: id,
    name: name,
    intention: intention,
    startDay: startDay,
    durationDays: durationDays,
    isActive: isActive,
    createdAt: createdAt,
  );
}

extension TrackerRowX on TrackerRow {
  Tracker toDomain() => Tracker(
    id: id,
    journeyId: journeyId,
    name: name,
    description: description,
    type: type,
    icon: icon,
    color: color,
    section: section,
    anchorMinutes: anchorMinutes,
    weekdays: weekdays,
    isRequired: isRequired,
    config: config,
    goal: goal,
    reminderEnabled: reminderEnabled,
    reminderMinutes: reminderMinutes,
    sortOrder: sortOrder,
    activeFrom: activeFrom,
    archivedOn: archivedOn,
  );
}

extension TrackerX on Tracker {
  /// Companion for insert (id omitted) or update (id included).
  TrackersCompanion toCompanion({bool includeId = false}) => TrackersCompanion(
    id: includeId ? Value(id) : const Value.absent(),
    journeyId: Value(journeyId),
    name: Value(name),
    description: Value(description),
    type: Value(type),
    icon: Value(icon),
    color: Value(color),
    section: Value(section),
    anchorMinutes: Value(anchorMinutes),
    weekdays: Value(weekdays),
    isRequired: Value(isRequired),
    config: Value(config),
    goal: Value(goal),
    reminderEnabled: Value(reminderEnabled),
    reminderMinutes: Value(reminderMinutes),
    sortOrder: Value(sortOrder),
    activeFrom: Value(activeFrom),
    archivedOn: Value(archivedOn),
  );
}

extension EntryRowX on EntryRow {
  Entry toDomain() => Entry(
    id: id,
    trackerId: trackerId,
    day: day,
    value: value,
    note: note,
    updatedAt: updatedAt,
  );
}

extension DashboardItemRowX on DashboardItemRow {
  DashboardItem? toDomain() {
    final k = DashboardWidgetKind.parse(kind);
    if (k == null) return null; // Unknown widget from a newer version.
    return DashboardItem(
      id: id,
      journeyId: journeyId,
      kind: k,
      size: size == WidgetSize.half.name ? WidgetSize.half : WidgetSize.full,
      config: config,
      sortOrder: sortOrder,
    );
  }
}
