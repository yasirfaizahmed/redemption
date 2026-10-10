import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/common.dart';
import '../../core/widgets/tracker_icons.dart';
import '../../domain/dashboard.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';

class DashboardEditorScreen extends ConsumerStatefulWidget {
  const DashboardEditorScreen({super.key});

  @override
  ConsumerState<DashboardEditorScreen> createState() =>
      _DashboardEditorScreenState();
}

class _DashboardEditorScreenState extends ConsumerState<DashboardEditorScreen> {
  List<DashboardItem>? _optimistic;

  Future<void> _reorder(List<DashboardItem> items, int from, int to) async {
    final list = [...items];
    list.insert(to, list.removeAt(from));
    setState(() => _optimistic = list);
    await ref.read(dashboardRepositoryProvider).reorder([
      for (final i in list) i.id,
    ]);
    if (mounted) setState(() => _optimistic = null);
  }

  Future<void> _add() async {
    final journey = ref.read(activeJourneyProvider).value;
    if (journey == null) return;
    final kind = await showModalBottomSheet<DashboardWidgetKind>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _Catalogue(),
    );
    if (kind == null || !mounted) return;
    var item = DashboardItem(
      id: 0,
      journeyId: journey.id,
      kind: kind,
      size: kind.canBeHalf ? WidgetSize.half : WidgetSize.full,
      config: DashboardItemConfig(
        rangeDays: kind == DashboardWidgetKind.trend ? 30 : 0,
      ),
    );
    if (kind.needsTrackers ||
        kind.needsSingleTracker ||
        kind == DashboardWidgetKind.statTile) {
      final configured = await _configure(item);
      if (configured == null) return;
      item = configured;
    }
    await ref.read(dashboardRepositoryProvider).add(item);
    if (mounted) showSnack(context, '${kind.label} added');
  }

  Future<DashboardItem?> _configure(DashboardItem item) =>
      showModalBottomSheet<DashboardItem>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _ConfigSheet(item: item),
      );

  @override
  Widget build(BuildContext context) {
    final items =
        _optimistic ?? ref.watch(dashboardItemsProvider).value ?? const [];
    final trackers = ref.watch(activeTrackersProvider);
    String trackerNames(List<int> ids) => [
      for (final id in ids)
        if (trackers.where((t) => t.id == id).firstOrNull case final t?) t.name,
    ].join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('Customise dashboard')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add widget'),
      ),
      body: items.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.widgets_outlined,
                title: 'No widgets',
                message: 'Tap “Add widget” to build your dashboard.',
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorderItem: (from, to) => _reorder(items, from, to),
              header: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Drag to reorder. Half-width widgets sit side by side.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              itemBuilder: (context, i) {
                final item = items[i];
                final details = [
                  if (item.config.title.isNotEmpty) '“${item.config.title}”',
                  if (item.config.trackerIds.isNotEmpty)
                    trackerNames(item.config.trackerIds),
                  if (item.kind == DashboardWidgetKind.statTile)
                    item.config.stat.label,
                  if (item.kind == DashboardWidgetKind.trend)
                    item.config.rangeDays == 0
                        ? 'Whole journey'
                        : 'Last ${item.config.rangeDays} days',
                ].where((s) => s.isNotEmpty).join(' · ');
                return Padding(
                  key: ValueKey(item.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.only(left: 4, right: 4),
                      leading: ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.drag_indicator_rounded),
                        ),
                      ),
                      title: Row(
                        children: [
                          Icon(item.kind.icon, size: 18),
                          const SizedBox(width: 8),
                          Flexible(child: Text(item.kind.label)),
                        ],
                      ),
                      subtitle: details.isEmpty
                          ? null
                          : Text(
                              details,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.kind.canBeHalf)
                            IconButton(
                              tooltip: item.isHalf
                                  ? 'Make full width'
                                  : 'Make half width',
                              onPressed: () => ref
                                  .read(dashboardRepositoryProvider)
                                  .update(
                                    item.copyWith(
                                      size: item.isHalf
                                          ? WidgetSize.full
                                          : WidgetSize.half,
                                    ),
                                  ),
                              icon: Icon(
                                item.isHalf
                                    ? Icons.view_agenda_outlined
                                    : Icons.view_column_outlined,
                              ),
                            ),
                          IconButton(
                            tooltip: 'Configure',
                            onPressed: () async {
                              final updated = await _configure(item);
                              if (updated != null) {
                                await ref
                                    .read(dashboardRepositoryProvider)
                                    .update(updated);
                              }
                            },
                            icon: const Icon(Icons.tune_rounded),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () => ref
                                .read(dashboardRepositoryProvider)
                                .remove(item.id),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _Catalogue extends StatelessWidget {
  const _Catalogue();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text('Add a widget', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final k in DashboardWidgetKind.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      k.icon,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(k.label),
                  subtitle: Text(k.description),
                  onTap: () => Navigator.pop(context, k),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConfigSheet extends ConsumerStatefulWidget {
  const _ConfigSheet({required this.item});
  final DashboardItem item;

  @override
  ConsumerState<_ConfigSheet> createState() => _ConfigSheetState();
}

class _ConfigSheetState extends ConsumerState<_ConfigSheet> {
  late DashboardItemConfig _config = widget.item.config;
  late final _title = TextEditingController(text: widget.item.config.title);

  DashboardWidgetKind get _kind => widget.item.kind;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _multi => _kind.needsTrackers;

  bool get _needsTracker =>
      _kind.needsSingleTracker ||
      _kind == DashboardWidgetKind.heatmap ||
      (_kind == DashboardWidgetKind.statTile && _config.stat.needsTracker);

  bool get _valid {
    if (_multi) return _config.trackerIds.isNotEmpty;
    if (_kind.needsSingleTracker) return _config.trackerId != null;
    if (_kind == DashboardWidgetKind.statTile && _config.stat.needsTracker) {
      return _config.trackerId != null;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var trackers = ref.watch(activeTrackersProvider);
    if (_kind == DashboardWidgetKind.trend) {
      // Charts make most sense for numbers and times; others show progress bars.
      trackers = [...trackers]
        ..sort(
          (a, b) => (b.type.isChartable ? 1 : 0) - (a.type.isChartable ? 1 : 0),
        );
    }
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_kind.label, style: theme.textTheme.titleLarge),
            Text(_kind.description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Custom title (optional)',
              ),
            ),
            if (_kind == DashboardWidgetKind.statTile) ...[
              const SizedBox(height: 16),
              Text('Statistic', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in StatKind.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _config.stat == s,
                      onSelected: (_) =>
                          setState(() => _config = _config.copyWith(stat: s)),
                    ),
                ],
              ),
            ],
            if (_kind == DashboardWidgetKind.trend) ...[
              const SizedBox(height: 16),
              Text('Range', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7d')),
                  ButtonSegment(value: 14, label: Text('14d')),
                  ButtonSegment(value: 30, label: Text('30d')),
                  ButtonSegment(value: 0, label: Text('All')),
                ],
                selected: {_config.rangeDays},
                onSelectionChanged: (s) => setState(
                  () => _config = _config.copyWith(rangeDays: s.first),
                ),
              ),
            ],
            if (_multi || _needsTracker) ...[
              const SizedBox(height: 16),
              Text(
                _multi
                    ? 'Trackers (tap in the order you want them)'
                    : _kind == DashboardWidgetKind.heatmap
                    ? 'Colour by tracker (or none for the daily score)'
                    : 'Tracker',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (trackers.isEmpty)
                const Text('Create some trackers first.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_kind == DashboardWidgetKind.heatmap)
                      ChoiceChip(
                        label: const Text('Daily score'),
                        selected: _config.trackerIds.isEmpty,
                        onSelected: (_) => setState(
                          () =>
                              _config = _config.copyWith(trackerIds: const []),
                        ),
                      ),
                    for (final t in trackers) _trackerChip(t),
                  ],
                ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _valid
                  ? () => Navigator.pop(
                      context,
                      widget.item.copyWith(
                        config: _config.copyWith(title: _title.text.trim()),
                      ),
                    )
                  : null,
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trackerChip(Tracker t) {
    final ids = _config.trackerIds;
    final selected = ids.contains(t.id);
    final order = selected && _multi ? ' ${ids.indexOf(t.id) + 1}' : '';
    return FilterChip(
      avatar: Icon(
        TrackerIcons.resolve(t.icon),
        size: 18,
        color: Color(t.color),
      ),
      label: Text('${t.name}$order'),
      selected: selected,
      showCheckmark: false,
      onSelected: (on) => setState(() {
        if (_multi) {
          final next = [...ids];
          on ? next.add(t.id) : next.remove(t.id);
          _config = _config.copyWith(trackerIds: next);
        } else {
          _config = _config.copyWith(trackerIds: on ? [t.id] : const []);
        }
      }),
    );
  }
}
