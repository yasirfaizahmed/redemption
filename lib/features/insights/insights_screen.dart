import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../app/theme/palette.dart';
import '../../core/widgets/common.dart';
import '../../domain/analytics.dart';
import '../../domain/formatting.dart';
import '../../state/providers.dart';
import '../charts/journey_grid.dart';
import '../charts/trend_chart.dart';
import '../dashboard/widgets/dashboard_cards.dart';
import 'day_detail_sheet.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Insights'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Journey'),
              Tab(text: 'Trackers'),
            ],
          ),
        ),
        body: const TabBarView(children: [_Overview(), _TrackerList()]),
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(journeyStatsProvider);
    if (stats == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        MetricGrid(
          children: [
            MetricTile(
              value: Fmt.percent(stats.consistency),
              label: 'Days won',
              icon: Icons.verified_rounded,
              color: Palette.success,
            ),
            MetricTile(
              value: '${stats.currentStreak}',
              label: 'Current streak',
              icon: Icons.local_fire_department_rounded,
              color: Palette.partial,
            ),
            MetricTile(
              value: '${stats.bestStreak}',
              label: 'Best streak',
              icon: Icons.emoji_events_rounded,
              color: Palette.gold,
            ),
            MetricTile(
              value: '${stats.perfectDays}',
              label: 'Perfect days',
              icon: Icons.star_rounded,
            ),
            MetricTile(
              value: Fmt.percent(stats.averageScore),
              label: 'Average score',
              icon: Icons.speed_rounded,
            ),
            MetricTile(
              value: '${stats.daysLeft}',
              label: 'Days left',
              icon: Icons.hourglass_bottom_rounded,
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          title: 'Every day of the journey',
          icon: Icons.grid_view_rounded,
          child: JourneyGrid(onDayTap: (d) => showDayDetailSheet(context, d)),
        ),
        const SizedBox(height: 12),
        const AppCard(
          title: 'Last 7 days',
          icon: Icons.bar_chart_rounded,
          child: WeekBars(),
        ),
        const SizedBox(height: 12),
        const PhaseCard(),
      ],
    );
  }
}

class _TrackerList extends ConsumerWidget {
  const _TrackerList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trackers = ref.watch(activeTrackersProvider);
    final stats = [
      for (final t in trackers)
        if (ref.watch(trackerStatsProvider(t.id)) case final TrackerStats s) s,
    ]..sort((a, b) => b.successRate.compareTo(a.successRate));
    if (stats.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.insights_rounded,
          title: 'No data yet',
          message: 'Insights appear as you log your days.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: stats.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final s = stats[i];
        final color = Color(s.tracker.color);
        return Card(
          child: InkWell(
            onTap: () => context.go(Routes.trackerDetail(s.tracker.id)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  TrackerAvatar(tracker: s.tracker, size: 42),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.tracker.name,
                                style: theme.textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              Fmt.percent(s.successRate),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: s.successRate,
                          color: color,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(6),
                          backgroundColor: color.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${s.doneDays}/${s.expectedDays} days · '
                          '🔥 ${s.currentStreak} · best ${s.bestStreak}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
