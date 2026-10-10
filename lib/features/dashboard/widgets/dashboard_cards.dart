import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../app/theme/palette.dart';
import '../../../core/time/day.dart';
import '../../../core/time/time_of_day_x.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../domain/analytics.dart';
import '../../../domain/dashboard.dart';
import '../../../domain/formatting.dart';
import '../../../domain/models.dart';
import '../../../domain/neuro_phase.dart';
import '../../../domain/quotes.dart';
import '../../../domain/scoring.dart';
import '../../../state/providers.dart';
import '../../charts/journey_grid.dart';
import '../../charts/trend_chart.dart';
import '../../entry/entry_sheet.dart';
import '../../insights/day_detail_sheet.dart';

/// Renders any [DashboardItem].
class DashboardWidgetView extends StatelessWidget {
  const DashboardWidgetView({super.key, required this.item, this.half = false});

  final DashboardItem item;

  /// Rendered in a half-width slot.
  final bool half;

  @override
  Widget build(BuildContext context) => switch (item.kind) {
    DashboardWidgetKind.journeyRing => JourneyRingCard(half: half),
    DashboardWidgetKind.todayProgress => TodayCard(half: half),
    DashboardWidgetKind.streak => StreakCard(half: half),
    DashboardWidgetKind.nextUp => const NextUpCard(),
    DashboardWidgetKind.todayStrip => TodayStripCard(config: item.config),
    DashboardWidgetKind.trackerRings => TrackerRingsCard(config: item.config),
    DashboardWidgetKind.heatmap => HeatmapCard(config: item.config),
    DashboardWidgetKind.trend => TrendCard(config: item.config),
    DashboardWidgetKind.weekBars => const AppCard(
      title: 'Last 7 days',
      icon: Icons.bar_chart_rounded,
      child: WeekBars(),
    ),
    DashboardWidgetKind.statTile => StatTileCard(
      config: item.config,
      half: half,
    ),
    DashboardWidgetKind.phase => const PhaseCard(),
    DashboardWidgetKind.motto => const MottoCard(),
  };
}

class _ConfigureHint extends StatelessWidget {
  const _ConfigureHint({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => AppCard(
    title: title,
    icon: icon,
    onTap: () => context.push(Routes.dashboardEdit),
    child: Text(
      'Pick trackers for this widget in “Customise dashboard”.',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}

// ---------------------------------------------------------------------------

class JourneyRingCard extends ConsumerWidget {
  const JourneyRingCard({super.key, this.half = false});
  final bool half;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(journeyStatsProvider);
    if (stats == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final j = stats.journey;
    final ring = ProgressRing(
      size: half ? 116 : 156,
      strokeWidth: half ? 11 : 14,
      progress: stats.elapsedFraction,
      secondaryProgress: stats.consistency,
      color: theme.colorScheme.primary,
      secondaryColor: Palette.gold,
      secondaryRingColor: Palette.success,
      semanticLabel:
          'Day ${stats.dayNumber} of ${j.durationDays}. '
          'Consistency ${Fmt.percent(stats.consistency)}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stats.hasStarted ? 'DAY' : 'STARTS IN',
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 2),
          ),
          FittedBox(
            child: Text(
              stats.hasStarted
                  ? '${stats.dayNumber}'
                  : '${j.startDay.difference(stats.today)}',
              style:
                  (half
                          ? theme.textTheme.headlineMedium
                          : theme.textTheme.displaySmall)
                      ?.copyWith(height: 1.05),
            ),
          ),
          Text(
            stats.hasStarted ? 'of ${j.durationDays}' : 'days',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    if (half) {
      return AppCard(
        onTap: () => context.go(Routes.insights),
        child: Column(
          children: [
            ring,
            const SizedBox(height: 10),
            Text(
              '${Fmt.percent(stats.consistency)} consistent',
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
      );
    }
    return AppCard(
      onTap: () => context.go(Routes.insights),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            j.name,
            style: theme.textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            stats.isFinished
                ? 'Journey complete. You did it.'
                : '${stats.phase.kind.title} phase · ${stats.phase.kind.tagline}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ring,
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RingStat(
                      color: theme.colorScheme.primary,
                      value: '${stats.daysLeft}',
                      label: 'days left',
                    ),
                    const SizedBox(height: 12),
                    _RingStat(
                      color: Palette.success,
                      value: Fmt.percent(stats.consistency),
                      label: 'days won',
                    ),
                    const SizedBox(height: 12),
                    _RingStat(
                      color: Palette.gold,
                      value: '${stats.perfectDays}',
                      label: stats.perfectDays == 1
                          ? 'perfect day'
                          : 'perfect days',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingStat extends StatelessWidget {
  const _RingStat({
    required this.color,
    required this.value,
    required this.label,
  });
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(value, style: theme.textTheme.titleLarge),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class TodayCard extends ConsumerWidget {
  const TodayCard({super.key, this.half = false});
  final bool half;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final s = ref.watch(daySummaryProvider(today));
    final ring = ProgressRing(
      size: half ? 84 : 72,
      strokeWidth: 9,
      progress: s.score,
      color: Palette.forScore(
        s.logged == 0 ? null : s.score,
        theme.colorScheme,
      ),
      semanticLabel: 'Today ${Fmt.percent(s.score)}',
      child: Text(
        Fmt.percent(s.score),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final text = Column(
      crossAxisAlignment: half
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text('Today', style: theme.textTheme.titleMedium),
        Text(
          s.isRestDay ? 'Rest day' : '${s.done} of ${s.expected} done',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    return AppCard(
      onTap: () => context.go(Routes.today),
      child: half
          ? Column(children: [ring, const SizedBox(height: 10), text])
          : Row(
              children: [
                ring,
                const SizedBox(width: 16),
                Expanded(child: text),
              ],
            ),
    );
  }
}

class StreakCard extends ConsumerWidget {
  const StreakCard({super.key, this.half = false});
  final bool half;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(journeyStatsProvider);
    final current = stats?.currentStreak ?? 0;
    final best = stats?.bestStreak ?? 0;
    final flame = Icon(
      Icons.local_fire_department_rounded,
      size: half ? 44 : 40,
      color: current > 0 ? Palette.partial : theme.colorScheme.outline,
    );
    final body = Column(
      crossAxisAlignment: half
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          '$current',
          style: theme.textTheme.displaySmall?.copyWith(height: 1),
        ),
        Text('day streak', style: theme.textTheme.labelLarge),
        Text(
          'Best: $best',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    return Semantics(
      label: 'Current streak $current days, best $best',
      excludeSemantics: true,
      child: AppCard(
        child: half
            ? Column(children: [flame, const SizedBox(height: 6), body])
            : Row(children: [flame, const SizedBox(width: 16), body]),
      ),
    );
  }
}

class NextUpCard extends ConsumerWidget {
  const NextUpCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final now = ref.watch(clockProvider);
    final settings = ref.watch(settingsValueProvider);
    final index = ref.watch(entryIndexProvider);
    final pending = [
      for (final t in ref.watch(activeTrackersProvider))
        if (t.isExpectedOn(today) && index.get(t.id, today) == null) t,
    ];
    if (pending.isEmpty) {
      return AppCard(
        title: 'Next up',
        icon: Icons.upcoming_rounded,
        child: Row(
          children: [
            const Icon(Icons.celebration_rounded, color: Palette.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Everything is logged for today. Rest well — tomorrow, again.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    final nowRel = Clock.relativeToDayStart(
      Clock.fromDateTime(now),
      settings.dayStartMinutes,
    );
    int rel(Tracker t) => t.anchorMinutes == null
        ? 1 << 20
        : Clock.relativeToDayStart(t.anchorMinutes!, settings.dayStartMinutes);
    // Most overdue first, then the soonest upcoming.
    final overdue = [
      for (final t in pending)
        if (rel(t) <= nowRel) t,
    ];
    final next = overdue.isNotEmpty ? overdue.first : pending.first;
    final r = rel(next);
    final timing = next.anchorMinutes == null
        ? 'Any time today'
        : r <= nowRel
        ? 'Planned ${Clock.format(next.anchorMinutes!, use24h: settings.use24h)} · '
              '${Clock.formatDuration(nowRel - r)} ago'
        : 'At ${Clock.format(next.anchorMinutes!, use24h: settings.use24h)} · '
              'in ${Clock.formatDuration(r - nowRel)}';
    return AppCard(
      title: 'Next up · ${pending.length} left today',
      icon: Icons.upcoming_rounded,
      onTap: () => showEntrySheet(context, trackerId: next.id, day: today),
      child: Row(
        children: [
          TrackerAvatar(tracker: next, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(next.name, style: theme.textTheme.titleLarge),
                Text(
                  timing,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: r <= nowRel && next.anchorMinutes != null
                        ? Palette.partial
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () =>
                showEntrySheet(context, trackerId: next.id, day: today),
            child: const Text('Log'),
          ),
        ],
      ),
    );
  }
}

class TodayStripCard extends ConsumerWidget {
  const TodayStripCard({super.key, required this.config});
  final DashboardItemConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final index = ref.watch(entryIndexProvider);
    final scoring = ref.watch(scoringProvider);
    final trackers = [
      for (final id in config.trackerIds)
        if (ref.watch(trackerByIdProvider(id)) case final t? when !t.isArchived)
          t,
    ];
    final title = config.title.isEmpty ? 'Quick strip' : config.title;
    if (trackers.isEmpty) {
      return _ConfigureHint(title: title, icon: Icons.track_changes_rounded);
    }
    final done = trackers
        .where(
          (t) =>
              scoring.status(t, index.get(t.id, today), today, today) ==
              EntryStatus.done,
        )
        .length;
    return AppCard(
      title: title,
      icon: Icons.track_changes_rounded,
      trailing: Text(
        '$done/${trackers.length}',
        style: theme.textTheme.labelLarge,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in trackers)
            Expanded(
              child: _StripItem(
                tracker: t,
                status: scoring.status(t, index.get(t.id, today), today, today),
                onTap: () =>
                    showEntrySheet(context, trackerId: t.id, day: today),
              ),
            ),
        ],
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({
    required this.tracker,
    required this.status,
    required this.onTap,
  });
  final Tracker tracker;
  final EntryStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '${tracker.name}: ${status.name}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              TrackerAvatar(tracker: tracker, status: status, size: 46),
              const SizedBox(height: 6),
              Text(
                tracker.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrackerRingsCard extends ConsumerWidget {
  const TrackerRingsCard({super.key, required this.config});
  final DashboardItemConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final journey = ref.watch(activeJourneyProvider).value;
    final stats = [
      for (final id in config.trackerIds)
        if (ref.watch(trackerStatsProvider(id)) case final s?
            when !s.tracker.isArchived)
          s,
    ];
    final title = config.title.isEmpty
        ? 'Road to ${journey?.durationDays ?? 90}'
        : config.title;
    if (stats.isEmpty) {
      return _ConfigureHint(title: title, icon: Icons.blur_circular_rounded);
    }
    return AppCard(
      title: title,
      icon: Icons.blur_circular_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final perRow = constraints.maxWidth > 420 ? 5 : 4;
          final w = (constraints.maxWidth - (perRow - 1) * 8) / perRow;
          return Wrap(
            spacing: 8,
            runSpacing: 14,
            children: [
              for (final s in stats)
                SizedBox(
                  width: w,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.go(Routes.trackerDetail(s.tracker.id)),
                    child: Column(
                      children: [
                        ProgressRing(
                          size: w.clamp(48, 72),
                          strokeWidth: 6,
                          progress: s.journeyProgress,
                          color: Color(s.tracker.color),
                          semanticLabel:
                              '${s.tracker.name}: ${s.doneDays} of ${s.plannedDays} days',
                          child: FittedBox(
                            child: Text(
                              '${s.doneDays}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.tracker.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall,
                        ),
                        Text(
                          '/${s.plannedDays}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class HeatmapCard extends ConsumerWidget {
  const HeatmapCard({super.key, required this.config});
  final DashboardItemConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracker = config.trackerId == null
        ? null
        : ref.watch(trackerByIdProvider(config.trackerId!));
    return AppCard(
      title: config.title.isNotEmpty
          ? config.title
          : tracker == null
          ? 'Journey grid'
          : '${tracker.name} grid',
      icon: Icons.grid_view_rounded,
      trailing: const _Legend(),
      child: JourneyGrid(
        trackerId: tracker?.id,
        onDayTap: (d) => showDayDetailSheet(context, d),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in const [0.0, 0.3, 0.6, 0.85, 1.0])
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                color: Palette.forScore(s, scheme),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

class TrendCard extends ConsumerWidget {
  const TrendCard({super.key, required this.config});
  final DashboardItemConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = config.trackerId;
    final tracker = id == null ? null : ref.watch(trackerByIdProvider(id));
    if (tracker == null) {
      return const _ConfigureHint(
        title: 'Trend chart',
        icon: Icons.show_chart_rounded,
      );
    }
    final stats = ref.watch(trackerStatsProvider(tracker.id));
    final use24h = ref.watch(settingsValueProvider.select((s) => s.use24h));
    final range = config.rangeDays <= 0
        ? 'journey'
        : '${config.rangeDays} days';
    return AppCard(
      title: config.title.isEmpty ? '${tracker.name} · $range' : config.title,
      icon: Icons.show_chart_rounded,
      trailing: stats?.average == null || !tracker.type.isChartable
          ? null
          : Text(
              'avg ${Fmt.aggregate(tracker, stats!.average!, use24h: use24h)}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
      onTap: () => context.go(Routes.trackerDetail(tracker.id)),
      child: TrendChart(trackerId: tracker.id, rangeDays: config.rangeDays),
    );
  }
}

class StatTileCard extends ConsumerWidget {
  const StatTileCard({super.key, required this.config, this.half = false});
  final DashboardItemConfig config;
  final bool half;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final use24h = ref.watch(settingsValueProvider.select((s) => s.use24h));
    final journeyStats = ref.watch(journeyStatsProvider);
    final stat = config.stat;
    TrackerStats? ts;
    if (stat.needsTracker) {
      final id = config.trackerId;
      ts = id == null ? null : ref.watch(trackerStatsProvider(id));
      if (ts == null) {
        return _ConfigureHint(
          title: stat.label,
          icon: Icons.analytics_outlined,
        );
      }
    }
    final t = ts?.tracker;
    final (String value, IconData icon) = switch (stat) {
      StatKind.successRate => (
        Fmt.percent(ts!.successRate),
        Icons.verified_rounded,
      ),
      StatKind.currentStreak => (
        '${ts!.currentStreak}d',
        Icons.local_fire_department_rounded,
      ),
      StatKind.bestStreak => ('${ts!.bestStreak}d', Icons.emoji_events_rounded),
      StatKind.average => (
        ts!.average == null
            ? '—'
            : Fmt.aggregate(t!, ts.average!, use24h: use24h),
        Icons.functions_rounded,
      ),
      StatKind.total => (
        ts!.total == null
            ? '${ts.loggedDays}×'
            : Fmt.aggregate(t!, ts.total!, use24h: use24h),
        Icons.add_chart_rounded,
      ),
      StatKind.lastValue => (
        ts!.lastEntry == null
            ? '—'
            : Fmt.value(t!, ts.lastEntry!.value, use24h: use24h),
        Icons.history_rounded,
      ),
      StatKind.journeyConsistency => (
        Fmt.percent(journeyStats?.consistency ?? 0),
        Icons.verified_rounded,
      ),
      StatKind.perfectDays => (
        '${journeyStats?.perfectDays ?? 0}',
        Icons.star_rounded,
      ),
      StatKind.daysLeft => (
        '${journeyStats?.daysLeft ?? 0}',
        Icons.hourglass_bottom_rounded,
      ),
      StatKind.averageScore => (
        Fmt.percent(journeyStats?.averageScore ?? 0),
        Icons.speed_rounded,
      ),
    };
    final color = t == null ? theme.colorScheme.primary : Color(t.color);
    final label = config.title.isNotEmpty
        ? config.title
        : t == null
        ? stat.label
        : '${t.name} · ${stat.label.toLowerCase()}';
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: AppCard(
        onTap: t == null ? null : () => context.go(Routes.trackerDetail(t.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: theme.textTheme.headlineMedium),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PhaseCard extends ConsumerStatefulWidget {
  const PhaseCard({super.key});

  @override
  ConsumerState<PhaseCard> createState() => _PhaseCardState();
}

class _PhaseCardState extends ConsumerState<PhaseCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = ref.watch(journeyStatsProvider);
    if (stats == null) return const SizedBox.shrink();
    final phase = stats.phase;
    return AppCard(
      title: 'Rewiring phase',
      icon: Icons.psychology_rounded,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final k in NeuroPhaseKind.values.map((p) => p.title))
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: k == phase.kind.title
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      k,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: k == phase.kind.title
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(phase.kind.tagline, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Text(
              phase.kind.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            secondChild: Text(
              phase.kind.description,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: phase.progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 6),
          Text(
            stats.isFinished
                ? 'All phases complete'
                : phase.kind == NeuroPhaseKind.redeem
                ? '${phase.daysToNext} days to the finish line'
                : '${phase.daysToNext} days to the next phase',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class MottoCard extends ConsumerWidget {
  const MottoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final journey = ref.watch(activeJourneyProvider).value;
    final pack = ref.watch(settingsValueProvider.select((s) => s.quotePack));
    final today = ref.watch(todayProvider);
    final dayNumber =
        journey?.dayNumber(today) ?? today.difference(const Day(2024, 1, 1));
    final quote = Quotes.ofTheDay(pack, dayNumber);
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer,
              Color.alphaBlend(
                Palette.gold.withValues(alpha: 0.18),
                scheme.primaryContainer,
              ),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (journey != null && journey.intention.isNotEmpty) ...[
              Text(
                'MY INTENTION',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.6,
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                journey.intention,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Icon(Icons.format_quote_rounded, color: scheme.onPrimaryContainer),
            Text(
              quote.text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onPrimaryContainer,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '— ${quote.source}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
