import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/palette.dart';
import '../../core/time/time_of_day_x.dart';
import '../../domain/analytics.dart';
import '../../domain/formatting.dart';
import '../../domain/models.dart';
import '../../domain/scoring.dart';
import '../../domain/tracker_goal.dart';
import '../../domain/tracker_type.dart';
import '../../state/providers.dart';

/// Line chart of a tracker's values with its target line. Non-numeric
/// trackers fall back to per-day progress bars.
class TrendChart extends ConsumerWidget {
  const TrendChart({
    super.key,
    required this.trackerId,
    this.rangeDays = 30,
    this.height = 180,
  });

  final int trackerId;

  /// Days of history (0 = whole journey so far).
  final int rangeDays;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracker = ref.watch(trackerByIdProvider(trackerId));
    final journey = ref.watch(activeJourneyProvider).value;
    if (tracker == null || journey == null) return SizedBox(height: height);
    final today = ref.watch(todayProvider);
    final scoring = ref.watch(scoringProvider);
    final settings = ref.watch(settingsValueProvider);
    final end = today.isAfter(journey.endDay) ? journey.endDay : today;
    var start = rangeDays <= 0
        ? journey.startDay
        : end.addDays(-(rangeDays - 1));
    if (start.isBefore(journey.startDay)) start = journey.startDay;
    if (end.isBefore(start)) return SizedBox(height: height);

    final series = buildSeries(
      tracker: tracker,
      index: ref.watch(entryIndexProvider),
      scoring: scoring,
      from: start,
      to: end,
    );
    final hasData = series.any((p) => p.value != null);
    if (!hasData) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Log ${tracker.name.toLowerCase()} to see the trend',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: tracker.type.isChartable
          ? _line(context, tracker, series, scoring, settings.use24h)
          : _bars(context, series),
    );
  }

  Widget _line(
    BuildContext context,
    Tracker tracker,
    List<SeriesPoint> series,
    Scoring scoring,
    bool use24h,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = Color(tracker.color);
    final values = [
      for (final p in series)
        if (p.value != null) p.value!,
    ];
    final goalY = _goalY(tracker, scoring);
    var minY = values.reduce(math.min);
    var maxY = values.reduce(math.max);
    if (goalY != null) {
      minY = math.min(minY, goalY);
      maxY = math.max(maxY, goalY);
    }
    final pad = math.max(
      (maxY - minY) * 0.15,
      tracker.type == TrackerType.time ? 15 : 1,
    );
    minY -= pad;
    maxY += pad;
    if (tracker.type != TrackerType.time) minY = math.max(0, minY);

    String label(double y) => tracker.type == TrackerType.time
        ? Clock.format(
            Clock.fromRelative(y.round(), scoring.dayStartMinutes),
            use24h: use24h,
          )
        : Fmt.aggregate(tracker, y, use24h: use24h);

    final spots = [
      for (final (i, p) in series.indexed)
        p.value == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), p.value!),
    ];

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: math.max(1, series.length - 1).toDouble(),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: tracker.type == TrackerType.time ? 46 : 42,
              getTitlesWidget: (v, meta) {
                if (v == meta.min || v == meta.max) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    label(v),
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: math.max(1, (series.length / 5).ceilToDouble()),
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= series.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    DateFormat('d/M').format(series[i].day.toDateTime()),
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (goalY != null)
              HorizontalLine(
                y: goalY,
                color: Palette.success.withValues(alpha: 0.8),
                strokeWidth: 1.5,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Palette.success,
                    fontWeight: FontWeight.w800,
                  ),
                  labelResolver: (_) => 'Goal ${label(goalY)}',
                ),
              ),
          ],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${DateFormat('EEE d MMM').format(series[s.x.round()].day.toDateTime())}\n${label(s.y)}',
                  theme.textTheme.labelMedium!.copyWith(
                    color: scheme.onInverseSurface,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              getDotPainter: (spot, _, _, i) => FlDotCirclePainter(
                radius: 3.5,
                color: _dotColor(series[i].progress, goalY != null, color),
                strokeWidth: 1.5,
                strokeColor: scheme.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 250),
    );
  }

  Widget _bars(BuildContext context, List<SeriesPoint> series) {
    final scheme = Theme.of(context).colorScheme;
    return BarChart(
      BarChartData(
        maxY: 100,
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        barTouchData: const BarTouchData(enabled: false),
        barGroups: [
          for (final (i, p) in series.indexed)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: p.value == null ? 0 : math.max(4, p.progress * 100),
                  width: math.max(3, 220 / series.length),
                  color: p.value == null
                      ? scheme.surfaceContainerHighest
                      : _dotColor(p.progress, true, scheme.primary),
                  borderRadius: BorderRadius.circular(3),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static Color _dotColor(double progress, bool hasGoal, Color fallback) {
    if (!hasGoal) return fallback;
    if (Scoring.isComplete(progress)) return Palette.success;
    if (progress > 0) return Palette.partial;
    return Palette.failure;
  }

  static double? _goalY(Tracker t, Scoring scoring) => switch (t.goal) {
    NumberGoal(:final value) => value,
    TimeGoal(:final minutes) => Clock.relativeToDayStart(
      minutes,
      scoring.dayStartMinutes,
    ).toDouble(),
    _ => null,
  };
}

/// Score bars for the last 7 days.
class WeekBars extends ConsumerWidget {
  const WeekBars({super.key, this.height = 140});
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final threshold = ref.watch(
      settingsValueProvider.select((s) => s.successThreshold),
    );
    final days = [for (var i = 6; i >= 0; i--) today.addDays(-i)];
    final summaries = [for (final d in days) ref.watch(daySummaryProvider(d))];
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: 100,
          minY: 0,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: threshold * 100,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    DateFormat('E').format(days[v.toInt()].toDateTime()),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: days[v.toInt()] == today
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                Fmt.percent(summaries[group.x].score),
                theme.textTheme.labelMedium!.copyWith(
                  color: scheme.onInverseSurface,
                ),
              ),
            ),
          ),
          barGroups: [
            for (final (i, s) in summaries.indexed)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: s.isRestDay ? 0 : math.max(3, s.score * 100),
                    width: 22,
                    color: Palette.forScore(
                      s.isRestDay || (days[i] == today && s.logged == 0)
                          ? null
                          : s.score,
                      scheme,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: 100,
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
