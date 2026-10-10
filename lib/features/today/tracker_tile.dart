import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/palette.dart';
import '../../core/time/day.dart';
import '../../core/time/time_of_day_x.dart';
import '../../core/widgets/common.dart';
import '../../domain/formatting.dart';
import '../../domain/models.dart';
import '../../domain/scoring.dart';
import '../../domain/tracker_goal.dart';
import '../../domain/tracker_type.dart';
import '../../domain/tracker_value.dart';
import '../../state/actions.dart';
import '../../state/providers.dart';
import '../entry/entry_sheet.dart';

/// One row of the daily timeline: time · rail node · card with quick action.
class TrackerTile extends ConsumerWidget {
  const TrackerTile({
    super.key,
    required this.tracker,
    required this.day,
    required this.isFirst,
    required this.isLast,
  });

  final Tracker tracker;
  final Day day;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(settingsValueProvider);
    final today = ref.watch(todayProvider);
    final entry = ref.watch(
      entryIndexProvider.select((i) => i.get(tracker.id, day)),
    );
    final scoring = ref.watch(scoringProvider);
    final status = scoring.status(tracker, entry, day, today);
    final statusColor = Palette.forStatus(status, scheme);
    final logged = entry != null && !entry.value.isEmpty;

    final subtitle = logged
        ? Fmt.value(tracker, entry.value, use24h: settings.use24h)
        : tracker.goal is LoggedGoal
        ? (tracker.isRequired ? 'Tap to log' : 'Optional · tap to log')
        : 'Goal: ${Fmt.goal(tracker, use24h: settings.use24h)}';

    void open() => showEntrySheet(context, trackerId: tracker.id, day: day);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 22),
              child: Text(
                tracker.anchorMinutes == null
                    ? ''
                    : Clock.format(
                        tracker.anchorMinutes!,
                        use24h: settings.use24h,
                      ),
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: _Rail(
              color: statusColor,
              filled: status == EntryStatus.done,
              isFirst: isFirst,
              isLast: isLast,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16, top: 5, bottom: 5),
              child: Semantics(
                button: true,
                label:
                    '${tracker.name}, ${_statusWord(status)}${logged ? ', $subtitle' : ''}',
                child: Card(
                  color: logged
                      ? Color.alphaBlend(
                          statusColor.withValues(alpha: 0.07),
                          scheme.surfaceContainerLow,
                        )
                      : null,
                  child: InkWell(
                    onTap: open,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              TrackerAvatar(tracker: tracker, status: status),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tracker.name,
                                      style: theme.textTheme.titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: logged
                                                ? scheme.onSurface
                                                : scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              _QuickAction(
                                tracker: tracker,
                                day: day,
                                entry: entry,
                                isToday: day == today,
                                onOpen: open,
                              ),
                            ],
                          ),
                          if (!logged && _showInlineChoices)
                            Padding(
                              padding: const EdgeInsets.only(top: 10, left: 56),
                              child: _InlineChoices(tracker: tracker, day: day),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _showInlineChoices =>
      tracker.type == TrackerType.singleChoice &&
      tracker.config.options.length <= 5 &&
      tracker.config.options.isNotEmpty;

  static String _statusWord(EntryStatus s) => switch (s) {
    EntryStatus.done => 'done',
    EntryStatus.partial => 'partially done',
    EntryStatus.failed => 'goal not met',
    EntryStatus.missed => 'missed',
    EntryStatus.pending => 'pending',
    EntryStatus.notExpected => 'not scheduled',
  };
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.color,
    required this.filled,
    required this.isFirst,
    required this.isLast,
  });

  final Color color;
  final bool filled;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(context).colorScheme.outlineVariant;
    return Column(
      children: [
        Container(
          width: 2,
          height: 24,
          color: isFirst ? Colors.transparent : line,
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : Theme.of(context).colorScheme.surface,
            border: Border.all(color: color, width: 2.5),
          ),
        ),
        Expanded(
          child: Container(width: 2, color: isLast ? Colors.transparent : line),
        ),
      ],
    );
  }
}

/// The one-tap shortcut at the end of each card.
class _QuickAction extends ConsumerWidget {
  const _QuickAction({
    required this.tracker,
    required this.day,
    required this.entry,
    required this.isToday,
    required this.onOpen,
  });

  final Tracker tracker;
  final Day day;
  final Entry? entry;
  final bool isToday;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final actions = ref.read(entryActionsProvider);
    final value = entry?.value;
    switch (tracker.type) {
      case TrackerType.checkbox:
        final done = value is BoolValue && value.value;
        return IconButton.filledTonal(
          tooltip: done ? 'Change' : 'Mark ${tracker.config.yesLabel}',
          isSelected: done,
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: done ? Palette.success : null,
            foregroundColor: done ? Colors.white : null,
          ),
          onPressed: done
              ? onOpen
              : () => actions.save(tracker, day, const BoolValue(true)),
          icon: const Icon(Icons.check_rounded),
        );
      case TrackerType.time when entry == null && isToday:
        return FilledButton.tonal(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          onPressed: () => actions.save(
            tracker,
            day,
            TimeValue(Clock.fromDateTime(DateTime.now())),
          ),
          child: const Text('Now'),
        );
      case TrackerType.counter:
        final count = value is NumberValue ? value.value : 0.0;
        final step = tracker.config.step <= 0 ? 1.0 : tracker.config.step;
        return IconButton.filledTonal(
          tooltip: 'Add ${Fmt.number(step)}',
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () {
            HapticFeedback.lightImpact();
            actions.save(
              tracker,
              day,
              NumberValue(count + step),
              note: entry?.note ?? '',
            );
          },
          icon: const Icon(Icons.add_rounded),
        );
      default:
        return Icon(
          Icons.chevron_right_rounded,
          color: scheme.onSurfaceVariant,
        );
    }
  }
}

/// Compact one-tap option buttons (e.g. prayer quality) shown while pending.
class _InlineChoices extends ConsumerWidget {
  const _InlineChoices({required this.tracker, required this.day});

  final Tracker tracker;
  final Day day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final o in tracker.config.options)
          Tooltip(
            message: o.label,
            child: Semantics(
              button: true,
              label: 'Log ${o.label}',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => ref
                    .read(entryActionsProvider)
                    .save(tracker, day, ChoiceValue(o.id)),
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 40,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Text(
                    o.emoji.isNotEmpty
                        ? (tracker.config.options.length <= 3
                              ? o.display
                              : o.emoji)
                        : o.label,
                    style:
                        o.emoji.isNotEmpty && tracker.config.options.length > 3
                        ? const TextStyle(fontSize: 18)
                        : theme.textTheme.labelLarge,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
