import 'package:material_ui/material_ui.dart';

/// Every widget that can live on the dashboard.
/// The enum `name` is persisted, so never rename existing values.
enum DashboardWidgetKind {
  journeyRing(
    label: 'Journey ring',
    description: 'Day X of N with your overall consistency.',
    icon: Icons.donut_large_rounded,
    canBeHalf: true,
  ),
  todayProgress(
    label: 'Today',
    description: 'Today’s score and how many items are done.',
    icon: Icons.today_rounded,
    canBeHalf: true,
  ),
  streak(
    label: 'Streak',
    description: 'Current and best run of winning days.',
    icon: Icons.local_fire_department_rounded,
    canBeHalf: true,
  ),
  nextUp(
    label: 'Next up',
    description: 'The next thing on your timeline, one tap to log.',
    icon: Icons.upcoming_rounded,
  ),
  todayStrip(
    label: 'Quick strip',
    description: 'Selected trackers as tappable status dots (e.g. 5 prayers).',
    icon: Icons.track_changes_rounded,
    needsTrackers: true,
  ),
  trackerRings(
    label: 'Tracker rings',
    description: 'Each tracker’s progress towards all N days.',
    icon: Icons.blur_circular_rounded,
    needsTrackers: true,
  ),
  heatmap(
    label: 'Journey grid',
    description: 'Every day of the journey as a coloured tile.',
    icon: Icons.grid_view_rounded,
  ),
  trend(
    label: 'Trend chart',
    description: 'A tracker’s values over time with its target line.',
    icon: Icons.show_chart_rounded,
    needsSingleTracker: true,
  ),
  weekBars(
    label: 'Last 7 days',
    description: 'Daily score bars for the past week.',
    icon: Icons.bar_chart_rounded,
  ),
  statTile(
    label: 'Stat tile',
    description: 'One number that matters: average, streak, success rate…',
    icon: Icons.analytics_outlined,
    canBeHalf: true,
  ),
  phase(
    label: 'Rewiring phase',
    description: 'Where you are in the neuroplasticity curve.',
    icon: Icons.psychology_rounded,
  ),
  motto(
    label: 'Intention & quote',
    description: 'Your niyyah and a daily reminder.',
    icon: Icons.format_quote_rounded,
  );

  const DashboardWidgetKind({
    required this.label,
    required this.description,
    required this.icon,
    this.canBeHalf = false,
    this.needsTrackers = false,
    this.needsSingleTracker = false,
  });

  final String label;
  final String description;
  final IconData icon;
  final bool canBeHalf;
  final bool needsTrackers;
  final bool needsSingleTracker;

  static DashboardWidgetKind? parse(String name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

enum WidgetSize { full, half }

/// Statistic shown by a [DashboardWidgetKind.statTile].
enum StatKind {
  successRate('Success rate', needsTracker: true),
  currentStreak('Current streak', needsTracker: true),
  bestStreak('Best streak', needsTracker: true),
  average('Average', needsTracker: true),
  total('Total', needsTracker: true),
  lastValue('Last value', needsTracker: true),
  journeyConsistency('Journey consistency'),
  perfectDays('Perfect days'),
  daysLeft('Days left'),
  averageScore('Average daily score');

  const StatKind(this.label, {this.needsTracker = false});
  final String label;
  final bool needsTracker;
}

@immutable
class DashboardItemConfig {
  const DashboardItemConfig({
    this.trackerIds = const [],
    this.rangeDays = 30,
    this.title = '',
    this.stat = StatKind.journeyConsistency,
  });

  factory DashboardItemConfig.fromJson(Map<String, dynamic> json) =>
      DashboardItemConfig(
        trackerIds: [
          for (final id in (json['trackers'] as List<dynamic>? ?? const []))
            id as int,
        ],
        rangeDays: json['range'] as int? ?? 30,
        title: json['title'] as String? ?? '',
        stat: StatKind.values.firstWhere(
          (s) => s.name == json['stat'],
          orElse: () => StatKind.journeyConsistency,
        ),
      );

  final List<int> trackerIds;

  /// Days of history to show (0 = whole journey).
  final int rangeDays;

  /// Optional custom title.
  final String title;
  final StatKind stat;

  int? get trackerId => trackerIds.isEmpty ? null : trackerIds.first;

  DashboardItemConfig copyWith({
    List<int>? trackerIds,
    int? rangeDays,
    String? title,
    StatKind? stat,
  }) => DashboardItemConfig(
    trackerIds: trackerIds ?? this.trackerIds,
    rangeDays: rangeDays ?? this.rangeDays,
    title: title ?? this.title,
    stat: stat ?? this.stat,
  );

  Map<String, dynamic> toJson() => {
    if (trackerIds.isNotEmpty) 'trackers': trackerIds,
    'range': rangeDays,
    if (title.isNotEmpty) 'title': title,
    'stat': stat.name,
  };
}

@immutable
class DashboardItem {
  const DashboardItem({
    required this.id,
    required this.journeyId,
    required this.kind,
    this.size = WidgetSize.full,
    this.config = const DashboardItemConfig(),
    this.sortOrder = 0,
  });

  final int id;
  final int journeyId;
  final DashboardWidgetKind kind;
  final WidgetSize size;
  final DashboardItemConfig config;
  final int sortOrder;

  bool get isHalf => size == WidgetSize.half && kind.canBeHalf;

  DashboardItem copyWith({
    int? id,
    int? journeyId,
    WidgetSize? size,
    DashboardItemConfig? config,
    int? sortOrder,
  }) => DashboardItem(
    id: id ?? this.id,
    journeyId: journeyId ?? this.journeyId,
    kind: kind,
    size: size ?? this.size,
    config: config ?? this.config,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}
