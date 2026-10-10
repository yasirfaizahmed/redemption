import 'package:redemption/core/time/day.dart';
import 'package:redemption/domain/models.dart';
import 'package:redemption/domain/tracker_config.dart';
import 'package:redemption/domain/tracker_goal.dart';
import 'package:redemption/domain/tracker_type.dart';
import 'package:redemption/domain/tracker_value.dart';

const start = Day(2026, 10, 1); // a Thursday

Tracker tracker({
  int id = 1,
  TrackerType type = TrackerType.checkbox,
  TrackerGoal goal = const BoolGoal(),
  TrackerConfig config = const TrackerConfig(),
  int weekdays = Weekdays.all,
  bool isRequired = true,
  Day activeFrom = start,
  Day? archivedOn,
  int? anchor,
}) => Tracker(
  id: id,
  journeyId: 1,
  name: 'T$id',
  type: type,
  icon: 'check',
  color: 0xFF10B981,
  activeFrom: activeFrom,
  archivedOn: archivedOn,
  goal: goal,
  config: config,
  weekdays: weekdays,
  isRequired: isRequired,
  anchorMinutes: anchor,
);

Journey journey({Day startDay = start, int days = 90}) => Journey(
  id: 1,
  name: 'Test',
  intention: '',
  startDay: startDay,
  durationDays: days,
  isActive: true,
  createdAt: DateTime(2026),
);

int _nextId = 1;

Entry entry(int trackerId, Day day, TrackerValue value) => Entry(
  id: _nextId++,
  trackerId: trackerId,
  day: day,
  value: value,
  updatedAt: DateTime(2026),
);
