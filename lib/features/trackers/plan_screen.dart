import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/time/time_of_day_x.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/progress_ring.dart';
import '../../domain/formatting.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  List<Tracker>? _optimistic;
  bool _showArchived = false;

  Future<void> _reorder(List<Tracker> list, int from, int to) async {
    final next = [...list];
    next.insert(to, next.removeAt(from));
    setState(() => _optimistic = next);
    await ref.read(trackerRepositoryProvider).reorder([
      for (final t in next) t.id,
    ]);
    if (mounted) setState(() => _optimistic = null);
  }

  Future<void> _sortByTime(List<Tracker> list) async {
    final sorted = [...list]
      ..sort((a, b) {
        final dayStart = ref.read(settingsValueProvider).dayStartMinutes;
        int key(Tracker t) => t.anchorMinutes == null
            ? 1 << 20
            : Clock.relativeToDayStart(t.anchorMinutes!, dayStart);
        return key(a).compareTo(key(b));
      });
    await ref.read(trackerRepositoryProvider).reorder([
      for (final t in sorted) t.id,
    ]);
    if (mounted) showSnack(context, 'Sorted by planned time');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final journey = ref.watch(activeJourneyProvider).value;
    final stats = ref.watch(journeyStatsProvider);
    final all = ref.watch(allTrackersProvider).value ?? const <Tracker>[];
    final active =
        _optimistic ??
        [
          for (final t in all)
            if (!t.isArchived) t,
        ];
    final archived = [
      for (final t in all)
        if (t.isArchived) t,
    ];
    final use24h = ref.watch(settingsValueProvider.select((s) => s.use24h));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan'),
        actions: [
          IconButton(
            tooltip: 'Sort by planned time',
            onPressed: active.length < 2 ? null : () => _sortByTime(active),
            icon: const Icon(Icons.sort_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(Routes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newTracker),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New tracker'),
      ),
      body: journey == null
          ? const SizedBox.shrink()
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: AppCard(
                      onTap: () => context.push(Routes.editJourney),
                      child: Row(
                        children: [
                          ProgressRing(
                            size: 64,
                            strokeWidth: 7,
                            progress: stats?.elapsedFraction ?? 0,
                            child: Text(
                              '${stats?.dayNumber ?? 0}',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  journey.name,
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${journey.durationDays} days · '
                                  '${DateFormat('d MMM').format(journey.startDay.toDateTime())}'
                                  ' – ${DateFormat('d MMM yyyy').format(journey.endDay.toDateTime())}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.edit_outlined),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SectionHeader(
                    'Daily trackers (${active.length})',
                    action: Text(
                      'drag to reorder',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
                if (active.isEmpty)
                  const SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.playlist_add_rounded,
                      title: 'No trackers yet',
                      message: 'Tap “New tracker” to add the first habit you want to rewire.',
                    ),
                  )
                else
                  SliverReorderableList(
                    itemCount: active.length,
                    onReorderItem: (from, to) => _reorder(active, from, to),
                    itemBuilder: (context, i) {
                      final t = active[i];
                      return Padding(
                        key: ValueKey(t.id),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.only(
                              left: 12,
                              right: 4,
                            ),
                            leading: TrackerAvatar(tracker: t, size: 40),
                            title: Text(t.name),
                            subtitle: Text(
                              [
                                t.type.label,
                                if (t.anchorMinutes != null)
                                  Clock.format(
                                    t.anchorMinutes!,
                                    use24h: use24h,
                                  ),
                                Weekdays.describe(t.weekdays),
                                if (!t.isRequired) 'optional',
                                if (t.reminderEnabled) '🔔',
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => context.push(Routes.editTracker(t.id)),
                            trailing: ReorderableDragStartListener(
                              index: i,
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(Icons.drag_handle_rounded),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                if (archived.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      title: Text('Archived (${archived.length})'),
                      trailing: Icon(
                        _showArchived ? Icons.expand_less : Icons.expand_more,
                      ),
                      onTap: () =>
                          setState(() => _showArchived = !_showArchived),
                    ),
                  ),
                  if (_showArchived)
                    SliverList.list(
                      children: [
                        for (final t in archived)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            leading: Opacity(
                              opacity: 0.5,
                              child: TrackerAvatar(tracker: t, size: 36),
                            ),
                            title: Text(t.name),
                            subtitle: Text(
                              'Archived ${DateFormat('d MMM').format(t.archivedOn!.toDateTime())}',
                            ),
                            trailing: TextButton(
                              onPressed: () => ref
                                  .read(trackerRepositoryProvider)
                                  .restore(t.id),
                              child: const Text('Restore'),
                            ),
                            onTap: () => context.push(Routes.editTracker(t.id)),
                          ),
                      ],
                    ),
                ],
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    child: Text(
                      'Trackers count towards your daily score unless marked optional. '
                      'Changing a goal re-scores past days too — '
                      '${Fmt.percent(ref.watch(settingsValueProvider).successThreshold)} '
                      'of the daily score wins the day.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
