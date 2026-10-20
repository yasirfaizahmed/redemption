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
  /// The wake-up time an alarm was just set for, and whether it worked.
  ({DateTime at, bool ok})? _alarm;
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
        _alarm = (at: w.at, ok: ok);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(settingsValueProvider);
    final now = ref.watch(clockProvider);
    final times = SleepCycles.wakeTimes(
      widget.bedtime,
      fallAsleepMinutes: settings.fallAsleepMinutes,
    );
    String time(DateTime t) =>
        Clock.format(Clock.fromDateTime(t), use24h: settings.use24h);
    final alarm = _alarm;
    final choices = {
      ...SleepCycles.fallAsleepChoices,
      settings.fallAsleepMinutes,
    }.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.alarm_rounded, color: scheme.primary),
            const SizedBox(width: 8),
            Text('Wake up fresh', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Sleep runs in ~90-minute cycles. Waking at the end of one feels '
          'lighter than waking mid-cycle. Tap a time to set an alarm.',
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
            passed: !w.at.isAfter(now),
            alarmSet: alarm != null && alarm.ok && alarm.at == w.at,
            onTap: _busy ? null : () => _setAlarm(w),
          ),
        if (alarm != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              alarm.ok
                  ? 'Alarm set for ${time(alarm.at)} in your Clock app.'
                  : 'Couldn’t reach the Clock app — set an alarm for '
                        '${time(alarm.at)} yourself.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: alarm.ok ? scheme.primary : scheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _WakeTile extends StatelessWidget {
  const _WakeTile({
    required this.time,
    required this.wake,
    required this.passed,
    required this.alarmSet,
    required this.onTap,
  });

  final String time;
  final WakeTime wake;
  final bool passed;
  final bool alarmSet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cycles = '${wake.cycles} ${wake.cycles == 1 ? 'cycle' : 'cycles'}';
    final sleep = Clock.formatDuration(wake.sleepMinutes);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: wake.isRecommended && !passed
          ? scheme.primaryContainer
          : scheme.surfaceContainerLow,
      child: ListTile(
        enabled: !passed,
        onTap: passed ? null : onTap,
        leading: Icon(
          alarmSet ? Icons.alarm_on_rounded : Icons.alarm_add_rounded,
          color: passed ? null : scheme.primary,
        ),
        title: Text(
          time,
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        subtitle: Text(
          [
            '$cycles · $sleep of sleep',
            if (passed) 'already passed' else if (alarmSet) 'alarm set',
          ].join(' · '),
        ),
        trailing: wake.isRecommended && !passed
            ? Text(
                'Recommended',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              )
            : null,
      ),
    );
  }
}
