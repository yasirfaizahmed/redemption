import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/common.dart';
import '../../domain/app_settings.dart';
import '../../domain/math_challenge.dart';
import '../../services/wake_alarm_service.dart';
import '../../state/providers.dart';

/// What the phone allows the alarm to do (re-read when Settings reopens).
final alarmChecksProvider = FutureProvider.autoDispose<AlarmChecks>(
  (ref) => ref.watch(wakeAlarmServiceProvider).checks(),
);

/// The "Wake-up alarm" block of the settings screen.
class WakeAlarmSection extends ConsumerStatefulWidget {
  const WakeAlarmSection({super.key});

  @override
  ConsumerState<WakeAlarmSection> createState() => _WakeAlarmSectionState();
}

class _WakeAlarmSectionState extends ConsumerState<WakeAlarmSection>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from a system screen: see what changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(alarmChecksProvider);
  }

  Future<void> _save(AppSettings Function(AppSettings) f) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.save(f(await repo.load()));
  }

  Future<void> _test() async {
    final service = ref.read(wakeAlarmServiceProvider);
    await ref.read(notificationServiceProvider).requestPermission();
    final ok = await service.schedule(
      DateTime.now().add(const Duration(seconds: 15)),
      label: 'Test alarm',
    );
    if (mounted) {
      showSnack(
        context,
        ok
            ? 'Test alarm in 15 seconds — lock the phone and wait.'
            : 'Couldn’t set the alarm — check notifications are allowed.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = ref.watch(settingsValueProvider);
    final service = ref.watch(wakeAlarmServiceProvider);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final children = <Widget>[const SectionHeader('Wake-up alarm')];
    if (!service.isSupported) {
      children.add(
        const ListTile(
          enabled: false,
          leading: Icon(Icons.alarm_off_rounded),
          title: Text('Redemption’s own alarm'),
          subtitle: Text('Available on Android'),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    final checks = ref.watch(alarmChecksProvider).value;
    final scheduled =
        ref.watch(scheduledWakeAlarmsProvider).value ?? const <WakeAlarm>[];
    final use24h = s.use24h;
    String when(DateTime t) =>
        DateFormat(use24h ? 'EEE d MMM, HH:mm' : 'EEE d MMM, h:mm a').format(t);

    children.addAll([
      SwitchListTile(
        secondary: const Icon(Icons.alarm_on_rounded),
        title: const Text('Ring in Redemption'),
        subtitle: const Text(
          'Wake-up times set an alarm here that rings at full volume until '
          'you solve the sums. Off: they go to your Clock app.',
        ),
        value: s.alarmInApp,
        onChanged: (v) => _save((x) => x.copyWith(alarmInApp: v)),
      ),
      if (s.alarmInApp) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text('Sums to stop it', style: theme.textTheme.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<MathDifficulty>(
            showSelectedIcon: false,
            segments: [
              for (final d in MathDifficulty.values)
                ButtonSegment(
                  value: d,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(d.label, maxLines: 1, softWrap: false),
                  ),
                ),
            ],
            selected: {s.alarmMathDifficulty},
            onSelectionChanged: (v) =>
                _save((x) => x.copyWith(alarmMathDifficulty: v.first)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text('e.g. ${s.alarmMathDifficulty.example}', style: muted),
        ),
        ListTile(
          title: const Text('How many in a row'),
          subtitle: Text(
            s.alarmMathCount == 1 ? 'One sum' : '${s.alarmMathCount} sums',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Fewer',
                onPressed: s.alarmMathCount > MathChallenge.minProblems
                    ? () => _save(
                        (x) => x.copyWith(alarmMathCount: s.alarmMathCount - 1),
                      )
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              IconButton(
                tooltip: 'More',
                onPressed: s.alarmMathCount < MathChallenge.maxProblems
                    ? () => _save(
                        (x) => x.copyWith(alarmMathCount: s.alarmMathCount + 1),
                      )
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        for (final a in scheduled)
          if (a.at.isAfter(ref.watch(clockProvider)))
            ListTile(
              leading: const Icon(Icons.alarm_rounded),
              title: Text(when(a.at)),
              subtitle: a.label.isEmpty ? null : Text(a.label),
              trailing: IconButton(
                tooltip: 'Cancel this alarm',
                onPressed: () => service.cancel(a.id),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
        ListTile(
          leading: const Icon(Icons.play_circle_outline_rounded),
          title: const Text('Test the alarm'),
          subtitle: const Text('Rings in 15 seconds'),
          onTap: _test,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'So nothing gets you out of it',
            style: theme.textTheme.titleSmall,
          ),
        ),
        _Check(
          icon: Icons.notifications_active_outlined,
          title: 'Notifications',
          ok: checks?.notifications,
          okText: 'Allowed — the ringing alarm can show',
          fixText: 'Needed for the alarm to ring and show',
          onFix: () => service.openSystemSetting('notifications'),
        ),
        _Check(
          icon: Icons.screen_lock_portrait_outlined,
          title: 'Over the lock screen',
          ok: checks?.fullScreen,
          okText: 'The sums open over the lock screen',
          fixText: 'Allow full-screen alerts so the sums open by themselves',
          onFix: () => service.openSystemSetting('fullScreen'),
        ),
        _Check(
          icon: Icons.battery_saver_outlined,
          title: 'Battery saving',
          ok: checks?.batteryUnrestricted,
          okText: 'Unrestricted — Android won’t put the alarm to sleep',
          fixText: 'Let Redemption run unrestricted so it rings on time',
          onFix: () => service.openSystemSetting('battery'),
        ),
        _Check(
          icon: Icons.shield_outlined,
          title: 'Alarm guard',
          ok: checks?.guard,
          okText:
              'On — while ringing: no power menu, no uninstalling, no Settings, '
              'no volume buttons',
          fixText:
              'Turn on “Redemption alarm guard” in Accessibility. While the '
              'alarm rings it blocks the power menu, uninstalling, Settings '
              'and the volume buttons.',
          onFix: () => service.openSystemSetting('accessibility'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'If Accessibility greys the guard out (“Restricted setting”), open '
            'App info → ⋮ → Allow restricted settings, then try again. The '
            'volume is held at maximum regardless. No app can stop a forced '
            'restart (holding the power button ~10 s) — if that happens, the '
            'alarm rings again once the phone is back on and you unlock it.',
            style: muted,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: TextButton.icon(
              onPressed: () => service.openSystemSetting('appInfo'),
              icon: const Icon(Icons.info_outline_rounded),
              label: const Text('Open App info'),
            ),
          ),
        ),
      ],
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.icon,
    required this.title,
    required this.ok,
    required this.okText,
    required this.fixText,
    required this.onFix,
  });

  final IconData icon;
  final String title;

  /// Null: unknown (still checking, or the phone can't say).
  final bool? ok;
  final String okText;
  final String fixText;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final good = ok ?? false;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(good ? okText : fixText),
      trailing: good
          ? Icon(Icons.check_circle_rounded, color: scheme.primary)
          : TextButton(onPressed: onFix, child: const Text('Fix')),
      onTap: good ? null : onFix,
    );
  }
}
