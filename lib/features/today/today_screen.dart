import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../app/theme/palette.dart';
import '../../core/time/day.dart';
import '../../core/time/time_of_day_x.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/progress_ring.dart';
import '../../domain/formatting.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../entry/entry_sheet.dart';
import 'tracker_tile.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key, this.openTrackerId});

  /// When set (e.g. from a notification), the entry sheet opens on load.
  final int? openTrackerId;

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  int? _handledOpenId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeOpenFromDeepLink();
  }

  @override
  void didUpdateWidget(TodayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeOpenFromDeepLink();
  }

  void _maybeOpenFromDeepLink() {
    final id = widget.openTrackerId;
    if (id == null || id == _handledOpenId) return;
    _handledOpenId = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(selectedDayProvider.notifier).select(null);
      showEntrySheet(context, trackerId: id, day: ref.read(todayProvider));
    });
  }

  Future<void> _pickDate(Journey journey, Day selected, Day today) async {
    final first = journey.startDay.isAfter(today) ? today : journey.startDay;
    final picked = await showDatePicker(
      context: context,
      initialDate: selected.toDateTime(),
      firstDate: first.toDateTime(),
      lastDate: today.toDateTime(),
      helpText: 'Jump to day',
    );
    if (picked != null) {
      ref.read(selectedDayProvider.notifier).select(Day.fromDateTime(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final journey = ref.watch(activeJourneyProvider).value;
    final day = ref.watch(effectiveSelectedDayProvider);
    final today = ref.watch(todayProvider);
    final trackers = ref.watch(activeTrackersProvider);
    final allTrackers =
        ref.watch(allTrackersProvider).value ?? const <Tracker>[];
    final summary = ref.watch(daySummaryProvider(day));
    final settings = ref.watch(settingsValueProvider);
    final now = ref.watch(clockProvider);

    if (journey == null) return const Scaffold();

    // Trackers relevant for the selected day (archived ones still show on the
    // days they were active, so history stays editable).
    final visible = [
      for (final t in allTrackers)
        if (t.isActiveOn(day)) t,
    ];
    final expected = [
      for (final t in visible)
        if (t.isScheduledOn(day)) t,
    ];
    final unscheduled = [
      for (final t in visible)
        if (!t.isScheduledOn(day)) t,
    ];

    final title = day == today
        ? 'Today'
        : day == today.addDays(-1)
        ? 'Yesterday'
        : DateFormat('EEEE').format(day.toDateTime());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Text(
              DateFormat('d MMMM yyyy').format(day.toDateTime()),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (day != today)
            TextButton(
              onPressed: () =>
                  ref.read(selectedDayProvider.notifier).select(null),
              child: const Text('Back to today'),
            ),
          IconButton(
            tooltip: 'Jump to date',
            onPressed: () => _pickDate(journey, day, today),
            icon: const Icon(Icons.calendar_month_rounded),
          ),
          IconButton(
            tooltip: 'Edit trackers',
            onPressed: () => context.go(Routes.plan),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: trackers.isEmpty && allTrackers.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.add_task_rounded,
                title: 'Nothing to track yet',
                message:
                    'Add the things you want to show up for every day — '
                    'prayers, meals, workouts, sleep… anything.',
                action: FilledButton.icon(
                  onPressed: () => context.push(Routes.newTracker),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add a tracker'),
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _DayStrip(
                    journey: journey,
                    selected: day,
                    today: today,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: _DayHeader(
                      journey: journey,
                      day: day,
                      score: summary.score,
                      done: summary.done,
                      expected: summary.expected,
                      threshold: settings.successThreshold,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(top: 4),
                  sliver: SliverList.list(
                    children: _timeline(
                      expected,
                      day: day,
                      showNow: day == today,
                      nowMinutes: Clock.fromDateTime(now),
                      dayStart: settings.dayStartMinutes,
                      use24h: settings.use24h,
                    ),
                  ),
                ),
                if (unscheduled.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _Unscheduled(trackers: unscheduled, day: day),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  List<Widget> _timeline(
    List<Tracker> trackers, {
    required Day day,
    required bool showNow,
    required int nowMinutes,
    required int dayStart,
    required bool use24h,
  }) {
    final out = <Widget>[];
    var nowPlaced = !showNow;
    String? section;
    final nowRel = Clock.relativeToDayStart(nowMinutes, dayStart);
    for (final (i, t) in trackers.indexed) {
      if (!nowPlaced &&
          t.anchorMinutes != null &&
          Clock.relativeToDayStart(t.anchorMinutes!, dayStart) > nowRel) {
        out.add(_NowLine(label: Clock.format(nowMinutes, use24h: use24h)));
        nowPlaced = true;
      }
      if (t.section.isNotEmpty && t.section != section) {
        section = t.section;
        out.add(
          SectionHeader(
            t.section,
            padding: const EdgeInsets.fromLTRB(80, 14, 16, 4),
          ),
        );
      }
      out.add(
        TrackerTile(
          key: ValueKey('tile-${t.id}'),
          tracker: t,
          day: day,
          isFirst: i == 0,
          isLast: i == trackers.length - 1,
        ),
      );
    }
    if (!nowPlaced && trackers.isNotEmpty) {
      out.add(_NowLine(label: Clock.format(nowMinutes, use24h: use24h)));
    }
    return out;
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Current time $label',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(child: Container(height: 2, color: scheme.primary)),
          ],
        ),
      ),
    );
  }
}

/// Horizontal strip of journey days with mini score rings.
class _DayStrip extends ConsumerStatefulWidget {
  const _DayStrip({
    required this.journey,
    required this.selected,
    required this.today,
  });

  final Journey journey;
  final Day selected;
  final Day today;

  @override
  ConsumerState<_DayStrip> createState() => _DayStripState();
}

class _DayStripState extends ConsumerState<_DayStrip> {
  static const _itemWidth = 52.0;
  ScrollController? _controller;

  List<Day> get _days {
    final start = widget.journey.startDay.isAfter(widget.today)
        ? widget.today
        : widget.journey.startDay;
    final end = widget.journey.endDay.isBefore(widget.today)
        ? widget.journey.endDay
        : widget.today;
    final days = Day.range(start, end).toList();
    if (days.isEmpty || days.last != widget.today) days.add(widget.today);
    return days;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    final selectedIndex = days
        .indexOf(widget.selected)
        .clamp(0, days.length - 1);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final initial =
            (selectedIndex * _itemWidth -
                    constraints.maxWidth / 2 +
                    _itemWidth / 2)
                .clamp(0.0, double.infinity);
        _controller ??= ScrollController(initialScrollOffset: initial);
        return SizedBox(
          height: 84,
          child: ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: days.length,
            itemExtent: _itemWidth,
            itemBuilder: (context, i) {
              final d = days[i];
              final summary = ref.watch(daySummaryProvider(d));
              final selected = d == widget.selected;
              return Semantics(
                button: true,
                selected: selected,
                label:
                    '${DateFormat('EEEE d MMMM').format(d.toDateTime())}, ${Fmt.percent(summary.score)}',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => ref.read(selectedDayProvider.notifier).select(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primaryContainer
                          : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E')
                              .format(d.toDateTime())
                              .substring(0, 1),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ProgressRing(
                          size: 34,
                          strokeWidth: 3.5,
                          progress: summary.isRestDay ? 0 : summary.score,
                          color: Palette.forScore(
                            summary.score,
                            theme.colorScheme,
                          ),
                          child: Text(
                            '${d.day}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: d == widget.today
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.journey,
    required this.day,
    required this.score,
    required this.done,
    required this.expected,
    required this.threshold,
  });

  final Journey journey;
  final Day day;
  final double score;
  final int done;
  final int expected;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = journey.dayNumber(day);
    final win = score >= threshold - 1e-9 && expected > 0;
    final color = Palette.forScore(
      expected == 0 ? null : score,
      theme.colorScheme,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ProgressRing(
              size: 76,
              strokeWidth: 9,
              progress: score,
              color: color,
              semanticLabel: 'Day score ${Fmt.percent(score)}',
              child: Text(
                Fmt.percent(score),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n >= 1 && n <= journey.durationDays
                          ? 'Day $n of ${journey.durationDays}'
                          : n < 1
                          ? 'Starts in ${1 - n} day${1 - n == 1 ? '' : 's'}'
                          : 'Journey complete',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expected == 0
                          ? 'Rest day — nothing required'
                          : '$done of $expected goals met'
                                '${win ? ' · day won' : ''}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          LinearProgressIndicator(
                            value: score,
                            minHeight: 8,
                            color: color,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                          // Win threshold marker.
                          Positioned.fill(
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: threshold.clamp(0, 1),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  width: 2,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Unscheduled extends StatefulWidget {
  const _Unscheduled({required this.trackers, required this.day});
  final List<Tracker> trackers;
  final Day day;

  @override
  State<_Unscheduled> createState() => _UnscheduledState();
}

class _UnscheduledState extends State<_Unscheduled> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.event_busy_rounded),
            title: Text('Not scheduled today (${widget.trackers.length})'),
            trailing: Icon(
              _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            ),
            onTap: () => setState(() => _open = !_open),
          ),
          if (_open)
            for (final t in widget.trackers)
              ListTile(
                leading: TrackerAvatar(tracker: t, size: 36),
                title: Text(t.name),
                subtitle: const Text('Optional today'),
                onTap: () =>
                    showEntrySheet(context, trackerId: t.id, day: widget.day),
              ),
        ],
      ),
    );
  }
}
