import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/time/time_of_day_x.dart';
import '../../domain/app_settings.dart';
import '../../domain/sleep_cycles.dart';
import '../../state/providers.dart';

/// After "Now" on a bedtime tracker: wake-up times on full sleep cycles.
Future<void> showWakeTimesSheet(
  BuildContext context, {
  required DateTime bedtime,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  // Cover the bottom navigation bar, and don't stay behind in the Today tab.
  useRootNavigator: true,
  builder: (_) => _WakeTimesSheet(bedtime: bedtime),
);

class _WakeTimesSheet extends ConsumerWidget {
  const _WakeTimesSheet({required this.bedtime});
  final DateTime bedtime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final settings = ref.watch(settingsValueProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sleep well', style: theme.textTheme.titleLarge),
          Text(
            'Bedtime logged at '
            '${Clock.format(Clock.fromDateTime(bedtime), use24h: settings.use24h)}',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          if (settings.quotePack != QuotePack.discipline) ...[
            const SizedBox(height: 8),
            Text(
              '“Bismika Allāhumma amūtu wa aḥyā” — In Your name, O Allah, '
              'I die and I live. (al-Bukhārī)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          WakeTimesPanel(bedtime: bedtime),
        ],
      ),
    );
  }
}

/// Wake-up times after 1–6 full ~90-minute sleep cycles from [bedtime],
/// in local time; tapping one sets an alarm in the Clock app.
class WakeTimesPanel extends ConsumerStatefulWidget {
  const WakeTimesPanel({super.key, required this.bedtime});
  final DateTime bedtime;

  @override
  ConsumerState<WakeTimesPanel> createState() => _WakeTimesPanelState();
}

class _WakeTimesPanelState extends ConsumerState<WakeTimesPanel> {
  /// Alarms set from this panel: each tap adds one in the Clock app.
  final _set = <DateTime>{};

  /// A time whose alarm the Clock app didn't take.
  DateTime? _failed;
  bool _busy = false;

  Future<void> _setFallAsleep(int minutes) async {
    final repo = ref.read(settingsRepositoryProvider);
    final s = await repo.load();
    await repo.save(s.copyWith(fallAsleepMinutes: minutes));
  }

  Future<void> _setAlarm(WakeTime w) async {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _busy = true);
    final ok = await ref
        .read(alarmServiceProvider)
        .setAlarm(
          hour: w.at.hour,
          minute: w.at.minute,
          message:
              'Wake up · ${w.cycles} sleep '
              '${w.cycles == 1 ? 'cycle' : 'cycles'}',
        );
    if (mounted) {
      setState(() {
        _busy = false;
        if (ok) {
          _set.add(w.at);
          _failed = null;
        } else {
          _failed = w.at;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(settingsValueProvider);
    final now = ref.watch(clockProvider);
    final canAlarm = ref.watch(alarmServiceProvider).isSupported;
    final times = SleepCycles.wakeTimes(
      widget.bedtime,
      fallAsleepMinutes: settings.fallAsleepMinutes,
    );
    String time(DateTime t) =>
        Clock.format(Clock.fromDateTime(t), use24h: settings.use24h);
    final choices = {
      ...SleepCycles.fallAsleepChoices,
      settings.fallAsleepMinutes,
    }.toList()..sort();
    final set = _set.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.alarm_rounded, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Wake up fresh', style: theme.textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Sleep runs in ~90-minute cycles. Waking at the end of one feels '
          'lighter than waking mid-cycle. '
          '${canAlarm ? 'Tap a time to set an alarm.' : 'Set your alarm for one of these times.'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Text('Time to fall asleep', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final m in choices)
              ChoiceChip(
                label: Text(m == 0 ? 'None' : '$m min'),
                selected: settings.fallAsleepMinutes == m,
                onSelected: (_) => _setFallAsleep(m),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final w in times)
          _WakeTile(
            time: time(w.at),
            wake: w,
            // The Clock app only takes hour:minute and rings at its next
            // occurrence, so a time a day or more away would ring too soon.
            state: !w.at.isAfter(now)
                ? _TileState.passed
                : w.at.difference(now) >= const Duration(hours: 24)
                ? _TileState.tooFar
                : _set.contains(w.at)
                ? _TileState.alarmSet
                : _failed == w.at
                ? _TileState.failed
                : _TileState.open,
            onTap: canAlarm && !_busy ? () => _setAlarm(w) : null,
          ),
        if (set.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              set.length == 1
                  ? 'Alarm set for ${time(set.single)} in your Clock app.'
                  : 'Alarms on in your Clock app: '
                        '${set.map(time).join(', ')}. Turn off any you '
                        'don’t need there.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
            ),
          ),
      ],
    );
  }
}

enum _TileState { open, alarmSet, failed, passed, tooFar }

class _WakeTile extends StatelessWidget {
  const _WakeTile({
    required this.time,
    required this.wake,
    required this.state,
    required this.onTap,
  });

  final String time;
  final WakeTime wake;
  final _TileState state;

  /// Null when no alarm can be set from here (the times are a guide).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final usable = state != _TileState.passed && state != _TileState.tooFar;
    final highlight = wake.isRecommended && usable;
    final cycles = '${wake.cycles} ${wake.cycles == 1 ? 'cycle' : 'cycles'}';
    final note = switch (state) {
      _TileState.passed => 'already passed',
      _TileState.tooFar => 'over a day away — set it closer to bedtime',
      _TileState.alarmSet => 'alarm set',
      _TileState.failed => 'couldn’t reach the Clock app — set it yourself',
      _TileState.open => null,
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: highlight ? scheme.primaryContainer : scheme.surfaceContainerLow,
      child: ListTile(
        enabled: usable,
        onTap: usable ? onTap : null,
        leading: Icon(
          switch (state) {
            _TileState.alarmSet => Icons.alarm_on_rounded,
            _TileState.failed => Icons.alarm_off_rounded,
            _ when onTap == null => Icons.schedule_rounded,
            _ => Icons.alarm_add_rounded,
          },
          color: !usable
              ? null
              : state == _TileState.failed
              ? scheme.error
              : scheme.primary,
        ),
        // The time never breaks across lines, even with large text.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            time,
            maxLines: 1,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        subtitle: Text(
          [
            '$cycles · ${Clock.formatDuration(wake.sleepMinutes)} of sleep',
            if (highlight) 'Recommended',
            ?note,
          ].join(' · '),
          style: state == _TileState.failed
              ? TextStyle(color: scheme.error)
              : null,
        ),
      ),
    );
  }
}
