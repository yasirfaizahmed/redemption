import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/palette.dart';
import '../../core/time/day.dart';
import '../../core/time/time_of_day_x.dart';
import '../../core/widgets/common.dart';
import '../../domain/formatting.dart';
import '../../domain/models.dart';
import '../../domain/scoring.dart';
import '../../domain/sleep_cycles.dart';
import '../../domain/tracker_config.dart';
import '../../domain/tracker_goal.dart';
import '../../domain/tracker_type.dart';
import '../../domain/tracker_value.dart';
import '../../state/actions.dart';
import '../../state/providers.dart';
import 'inputs/tracker_input.dart';
import 'wake_times.dart';

/// Opens the log sheet for [trackerId] on [day].
Future<void> showEntrySheet(
  BuildContext context, {
  required int trackerId,
  required Day day,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  // Cover the bottom navigation bar too.
  useRootNavigator: true,
  builder: (_) => EntrySheet(trackerId: trackerId, day: day),
);

class EntrySheet extends ConsumerStatefulWidget {
  const EntrySheet({super.key, required this.trackerId, required this.day});

  final int trackerId;
  final Day day;

  @override
  ConsumerState<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<EntrySheet> {
  TrackerValue? _draft;
  late final TextEditingController _note;
  bool _noteOpen = false;
  bool _saving = false;
  Entry? _existing;

  @override
  void initState() {
    super.initState();
    _existing = ref.read(entryIndexProvider).get(widget.trackerId, widget.day);
    final tracker = ref.read(trackerByIdProvider(widget.trackerId));
    _draft = _existing?.value ?? _defaultDraft(tracker);
    _note = TextEditingController(text: _existing?.note ?? '');
    // Trackers that ask for a comment (e.g. "What did you train?") open
    // with the comment box, and don't save on the first tap.
    _noteOpen =
        _note.text.isNotEmpty ||
        (tracker?.config.notePrompt.isNotEmpty ?? false);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Time trackers start at "now" so a single tap on Save logs it.
  /// Time trackers start pre-filled so one tap on Save logs them: "now" when
  /// logging around (or after) the planned time, otherwise the planned time.
  TrackerValue? _defaultDraft(Tracker? t) {
    if (t == null || t.type != TrackerType.time) return null;
    final anchor = t.anchorMinutes;
    if (widget.day != ref.read(todayProvider)) {
      return anchor == null ? null : TimeValue(anchor);
    }
    final now = Clock.fromDateTime(ref.read(clockProvider));
    final dayStart = ref.read(settingsValueProvider).dayStartMinutes;
    final earlyBy =
        (anchor == null ? 0 : Clock.relativeToDayStart(anchor, dayStart)) -
        Clock.relativeToDayStart(now, dayStart);
    return TimeValue(anchor != null && earlyBy > 120 ? anchor : now);
  }

  Future<void> _save(Tracker tracker) async {
    if (_saving) return;
    setState(() => _saving = true);
    // Answering "What did you train?" without tapping an answer means it
    // happened: log the win so the comment isn't stored without points.
    // Info-only comments ("What did you eat?") never earn anything.
    final value =
        (_draft == null || _draft!.isEmpty) &&
            tracker.type == TrackerType.checkbox &&
            tracker.config.notePrompt.isNotEmpty &&
            !tracker.config.noteIsInfoOnly &&
            _note.text.trim().isNotEmpty
        ? BoolValue(tracker.winAnswer)
        : _draft;
    await ref
        .read(entryActionsProvider)
        .save(tracker, widget.day, value, note: _note.text);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clear(Tracker tracker) async {
    await ref.read(entryActionsProvider).clear(tracker, widget.day);
    if (mounted) Navigator.of(context).pop();
  }

  void _onChanged(Tracker tracker, TrackerValue? v) {
    setState(() => _draft = v);
    if (tracker.type.savesInstantly && v != null && !_noteOpen) {
      _save(tracker);
    }
  }

  Future<void> _addOption(Tracker tracker, ChoiceOption option) => ref
      .read(trackerRepositoryProvider)
      .update(
        tracker.copyWith(
          config: tracker.config.copyWith(
            options: [...tracker.config.options, option],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tracker = ref.watch(trackerByIdProvider(widget.trackerId));
    if (tracker == null) return const SizedBox(height: 200);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsValueProvider);
    final journey = ref.watch(activeJourneyProvider).value;
    final scoring = ref.watch(scoringProvider);
    final index = ref.watch(entryIndexProvider);
    final stats = ref.watch(trackerStatsProvider(tracker.id));
    final today = ref.watch(todayProvider);

    final previous = index.get(tracker.id, widget.day.addDays(-1))?.value;
    final last = stats?.lastEntry;
    final lastNumber =
        last != null && last.day != widget.day && last.value is NumberValue
        ? (last.value as NumberValue).value
        : null;

    final dayLabel = widget.day == today
        ? 'Today'
        : widget.day == today.addDays(-1)
        ? 'Yesterday'
        : DateFormat('EEE, d MMM').format(widget.day.toDateTime());
    final dayNumber = journey?.dayNumber(widget.day);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                TrackerAvatar(tracker: tracker, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tracker.name, style: theme.textTheme.titleLarge),
                      Text(
                        [
                          dayLabel,
                          if (dayNumber != null && dayNumber > 0)
                            'Day $dayNumber',
                          if (!tracker.isRequired) 'Optional',
                        ].join(' · '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (tracker.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(tracker.description, style: theme.textTheme.bodyMedium),
            ],
            if (!tracker.isScheduledOn(widget.day)) ...[
              const SizedBox(height: 12),
              const _Banner(
                icon: Icons.event_busy_rounded,
                text: 'Not scheduled on this day — logging is optional.',
              ),
            ] else if (tracker.skipReasonOn(
                  index.forDay(widget.day),
                  ref.watch(allTrackersProvider).value ?? const [],
                )
                case final reason?) ...[
              const SizedBox(height: 12),
              _Banner(
                icon: Icons.event_busy_rounded,
                text: reason.isEmpty
                    ? 'Not needed on this day — logging is optional.'
                    : 'Not needed on this day ($reason) — logging is optional.',
              ),
            ],
            if (tracker.ruleOn(index.forDay(widget.day)) case final rule?
                when rule.label.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Banner(icon: Icons.business_center_outlined, text: rule.label),
            ],
            const SizedBox(height: 16),
            _GoalHint(
              tracker: tracker,
              progress: scoring.progress(
                tracker,
                _draft,
                sameDay: index.forDay(widget.day),
              ),
              hasValue: _draft != null && !_draft!.isEmpty,
              use24h: settings.use24h,
            ),
            const SizedBox(height: 20),
            TrackerInput(
              // On rule days (e.g. office days) options show today's credit.
              tracker: switch (tracker.ruleOn(index.forDay(widget.day))) {
                final rule? => tracker.withRuleCredits(rule),
                null => tracker,
              },
              value: _draft,
              use24h: settings.use24h,
              onChanged: (v) => _onChanged(tracker, v),
              suggestions: ref.watch(textSuggestionsProvider(tracker.id)),
              previousText: previous is TextValue ? previous.text : null,
              lastNumber: lastNumber,
              onAddOption: (o) => _addOption(tracker, o),
            ),
            // A bedtime logged for today: alarms on full sleep cycles.
            if (_draft case TimeValue(:final minutes)
                when tracker.suggestsWakeTimes && widget.day == today) ...[
              const SizedBox(height: 16),
              WakeTimesPanel(
                bedtime: SleepCycles.bedtimeOn(
                  widget.day,
                  minutes,
                  dayStartMinutes: settings.dayStartMinutes,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_noteOpen)
              TextField(
                controller: _note,
                minLines: tracker.config.notePrompt.isEmpty ? 1 : 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: tracker.config.notePrompt.isEmpty
                      ? 'Note'
                      : tracker.config.notePrompt,
                  hintText: tracker.config.notePrompt.isEmpty
                      ? null
                      : tracker.config.placeholder,
                  prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _noteOpen = true),
                  icon: const Icon(Icons.sticky_note_2_outlined),
                  label: const Text('Add a note'),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_existing != null)
                  TextButton.icon(
                    onPressed: () => _clear(tracker),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Clear'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _save(tracker),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// Live feedback on the goal as the user adjusts the value.
class _GoalHint extends StatelessWidget {
  const _GoalHint({
    required this.tracker,
    required this.progress,
    required this.hasValue,
    required this.use24h,
  });

  final Tracker tracker;
  final double progress;
  final bool hasValue;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = tracker.goal;
    final complete = Scoring.isComplete(progress);
    final color = !hasValue
        ? theme.colorScheme.outline
        : complete
        ? Palette.success
        : progress > 0
        ? Palette.partial
        : Palette.failure;
    final label = !hasValue
        ? 'Goal: ${Fmt.goal(tracker, use24h: use24h)}'
        : complete
        ? (goal is LoggedGoal ? 'Logged' : 'Goal met')
        : progress > 0
        ? 'Partial credit · ${Fmt.percent(progress)}'
        : 'Goal not met';
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              !hasValue
                  ? Icons.flag_outlined
                  : complete
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: color),
              ),
            ),
            if (hasValue && goal is! LoggedGoal)
              Text(
                Fmt.goal(tracker, use24h: use24h),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
