import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../app/theme/palette.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/progress_ring.dart';
import '../../domain/formatting.dart';
import '../../domain/models.dart';
import '../../domain/tracker_type.dart';
import '../../domain/tracker_value.dart';
import '../../state/providers.dart';
import '../charts/journey_grid.dart';
import '../charts/trend_chart.dart';
import '../entry/entry_sheet.dart';
import '../entry/inputs/attachment_input.dart';

class TrackerDetailScreen extends ConsumerStatefulWidget {
  const TrackerDetailScreen({super.key, required this.trackerId});
  final int trackerId;

  @override
  ConsumerState<TrackerDetailScreen> createState() =>
      _TrackerDetailScreenState();
}

class _TrackerDetailScreenState extends ConsumerState<TrackerDetailScreen> {
  int _range = 30;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tracker = ref.watch(trackerByIdProvider(widget.trackerId));
    final stats = ref.watch(trackerStatsProvider(widget.trackerId));
    if (tracker == null || stats == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Tracker not found')),
      );
    }
    final use24h = ref.watch(settingsValueProvider.select((s) => s.use24h));
    final index = ref.watch(entryIndexProvider);
    final entries = index.forTracker(tracker.id).values.toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    final color = Color(tracker.color);
    final store = ref.watch(attachmentStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tracker.name),
        actions: [
          IconButton(
            tooltip: 'Edit tracker',
            onPressed: () => context.push(Routes.editTracker(tracker.id)),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          AppCard(
            child: Row(
              children: [
                ProgressRing(
                  progress: stats.journeyProgress,
                  color: color,
                  semanticLabel:
                      '${stats.doneDays} of ${stats.plannedDays} planned days achieved',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${stats.doneDays}',
                        style: theme.textTheme.headlineMedium,
                      ),
                      Text(
                        'of ${stats.plannedDays}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Goal', style: theme.textTheme.labelMedium),
                      Text(
                        Fmt.goal(tracker, use24h: use24h),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${Fmt.percent(stats.successRate)} success · '
                        '${stats.loggedDays} logged',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '🔥 ${stats.currentStreak} now · best ${stats.bestStreak}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (tracker.type.isChartable && stats.average != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      value: Fmt.aggregate(
                        tracker,
                        stats.average!,
                        use24h: use24h,
                      ),
                      label: 'Average',
                      icon: Icons.functions_rounded,
                      color: color,
                    ),
                  ),
                  if (stats.total != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricTile(
                        value: Fmt.aggregate(
                          tracker,
                          stats.total!,
                          use24h: use24h,
                        ),
                        label: 'Total',
                        icon: Icons.add_chart_rounded,
                        color: color,
                      ),
                    ),
                  ],
                  if (stats.lastEntry != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricTile(
                        value: Fmt.value(
                          tracker,
                          stats.lastEntry!.value,
                          use24h: use24h,
                        ),
                        label: 'Last',
                        icon: Icons.history_rounded,
                        color: color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          AppCard(
            title: 'Trend',
            icon: Icons.show_chart_rounded,
            trailing: SegmentedButton<int>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: 7, label: Text('7d')),
                ButtonSegment(value: 30, label: Text('30d')),
                ButtonSegment(value: 0, label: Text('All')),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
            child: TrendChart(
              trackerId: tracker.id,
              rangeDays: _range,
              height: 200,
            ),
          ),
          if (stats.optionCounts.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              title: 'Breakdown',
              icon: Icons.pie_chart_outline_rounded,
              child: _Distribution(
                tracker: tracker,
                counts: stats.optionCounts,
              ),
            ),
          ],
          const SizedBox(height: 12),
          AppCard(
            title: 'Journey grid',
            icon: Icons.grid_view_rounded,
            child: JourneyGrid(
              trackerId: tracker.id,
              onDayTap: (d) =>
                  showEntrySheet(context, trackerId: tracker.id, day: d),
            ),
          ),
          if (tracker.type == TrackerType.image) ...[
            const SizedBox(height: 12),
            AppCard(
              title: 'Gallery',
              icon: Icons.photo_library_outlined,
              child: Builder(
                builder: (context) {
                  final photos = [
                    for (final e in entries)
                      if (e.value case AttachmentsValue(:final files))
                        for (final f in files) (e.day, f),
                  ];
                  if (photos.isEmpty) return const Text('No photos yet.');
                  return GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (final (day, f) in photos)
                        InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ImageViewer(
                                file: store.resolve(f),
                                title: DateFormat('d MMM yyyy')
                                    .format(day.toDateTime()),
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              store.resolve(f),
                              fit: BoxFit.cover,
                              cacheWidth: 300,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SectionHeader(
            'History',
            padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nothing logged yet.'),
            ),
          for (final e in entries.take(60))
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(
                Fmt.value(tracker, e.value, use24h: use24h),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  DateFormat('EEE, d MMM').format(e.day.toDateTime()),
                  if (e.note.isNotEmpty) e.note,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              leading: Icon(
                Icons.circle,
                size: 12,
                color: _statusColor(ref, tracker, e),
              ),
              onTap: () =>
                  showEntrySheet(context, trackerId: tracker.id, day: e.day),
            ),
        ],
      ),
    );
  }

  Color _statusColor(WidgetRef ref, Tracker t, Entry e) {
    final p = ref.read(scoringProvider).progress(t, e.value);
    if (p >= 0.999) return Palette.success;
    if (p > 0) return Palette.partial;
    return Palette.failure;
  }
}

class _Distribution extends StatelessWidget {
  const _Distribution({required this.tracker, required this.counts});
  final Tracker tracker;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final rows = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    String label(String id) => switch (id) {
      'yes' when tracker.type == TrackerType.checkbox =>
        tracker.config.yesLabel,
      'no' when tracker.type == TrackerType.checkbox => tracker.config.noLabel,
      _ => tracker.config.optionById(id)?.display ?? id,
    };
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label(r.key),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${r.value}× · ${Fmt.percent(r.value / total)}',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: r.value / total,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(6),
                  color: Color(tracker.color),
                  backgroundColor: Color(tracker.color).withValues(alpha: 0.12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
