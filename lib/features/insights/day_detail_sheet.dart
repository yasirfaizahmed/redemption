import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/palette.dart';
import '../../core/time/day.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/progress_ring.dart';
import '../../domain/formatting.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../entry/entry_sheet.dart';

Future<void> showDayDetailSheet(BuildContext context, Day day) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, controller) =>
            _DayDetail(day: day, controller: controller),
      ),
    );

class _DayDetail extends ConsumerWidget {
  const _DayDetail({required this.day, required this.controller});

  final Day day;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final journey = ref.watch(activeJourneyProvider).value;
    final trackers = [
      for (final t in ref.watch(allTrackersProvider).value ?? const <Tracker>[])
        if (t.isActiveOn(day)) t,
    ];
    final index = ref.watch(entryIndexProvider);
    final scoring = ref.watch(scoringProvider);
    final today = ref.watch(todayProvider);
    final summary = ref.watch(daySummaryProvider(day));
    final use24h = ref.watch(settingsValueProvider.select((s) => s.use24h));

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          children: [
            ProgressRing(
              size: 64,
              strokeWidth: 7,
              progress: summary.score,
              color: Palette.forScore(summary.score, theme.colorScheme),
              child: Text(
                Fmt.percent(summary.score),
                style: theme.textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, d MMMM').format(day.toDateTime()),
                    style: theme.textTheme.titleLarge,
                  ),
                  if (journey != null)
                    Text(
                      'Day ${journey.dayNumber(day)} · '
                      '${summary.done}/${summary.expected} goals met',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final t in trackers)
          () {
            final entry = index.get(t.id, day);
            final sameDay = index.forDay(day);
            final status = scoring.status(
              t,
              entry,
              day,
              today,
              sameDay: sameDay,
            );
            final skipReason = t.skipReasonOn(sameDay, trackers);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: TrackerAvatar(
                tracker: t,
                size: 40,
                status: status,
                entry: entry,
              ),
              title: Text(t.name),
              subtitle: Text(
                [
                  if (entry == null || entry.value.isEmpty)
                    if (!t.isScheduledOn(day))
                      'Not scheduled'
                    else if (skipReason != null)
                      'Not needed — $skipReason'
                    else
                      'Not logged'
                  else
                    Fmt.value(t, entry.value, use24h: use24h),
                  if (entry != null && entry.note.isNotEmpty) '“${entry.note}”',
                ].join('\n'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(
                Palette.iconFor(t, entry, status),
                color: Palette.forStatus(status, theme.colorScheme),
              ),
              onTap: () => showEntrySheet(context, trackerId: t.id, day: day),
            );
          }(),
      ],
    );
  }
}
