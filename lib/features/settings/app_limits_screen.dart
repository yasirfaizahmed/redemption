import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/common.dart';
import '../../services/app_limits_service.dart';
import '../../state/providers.dart';

/// The limits and today's use, as the phone keeps them.
final appLimitsProvider = FutureProvider.autoDispose<AppLimitsState>(
  (ref) => ref.watch(appLimitsServiceProvider).load(),
);

String formatMinutes(int m) {
  if (m == 0) return '0 min';
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '$h h' : '$h h $r min';
}

/// Daily limits for Chrome, Instagram, YouTube, YouTube Music and Spotify:
/// set once, never raised or removed, back each day at midnight.
class AppLimitsScreen extends ConsumerStatefulWidget {
  const AppLimitsScreen({super.key});

  @override
  ConsumerState<AppLimitsScreen> createState() => _AppLimitsScreenState();
}

class _AppLimitsScreenState extends ConsumerState<AppLimitsScreen>
    with WidgetsBindingObserver {
  /// Limits chosen here but not yet locked.
  final _draft = <String, int>{};
  Timer? _refresh;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Today's use keeps changing while the screen is open.
    _refresh = Timer.periodic(
      const Duration(seconds: 30),
      (_) => ref.invalidate(appLimitsProvider),
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(appLimitsProvider);
  }

  Future<void> _save(
    AppLimitsState current,
    Map<String, int> changes, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final ok = await confirm(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    final error = await ref.read(appLimitsServiceProvider).lock({
      ...current.quotas,
      ...changes,
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (error == null) {
        for (final id in changes.keys) {
          _draft.remove(id);
        }
      }
    });
    ref.invalidate(appLimitsProvider);
    showSnack(context, error ?? 'Locked.');
  }

  Future<void> _lockDraft(AppLimitsState current) {
    final lines = [
      for (final a in LimitedApp.all)
        if (_draft[a.id] case final m?)
          m == 0
              ? '• ${a.name}: blocked all day'
              : '• ${a.name}: ${formatMinutes(m)} a day',
    ].join('\n');
    return _save(
      current,
      Map.of(_draft),
      title: 'Lock these limits for good?',
      message:
          '$lines\n\n'
          'Once locked, a limit can never be raised or removed — only made '
          'stricter. Each day’s time starts again at midnight.',
      confirmLabel: 'Lock for good',
    );
  }

  Future<void> _makeStricter(
    AppLimitsState current,
    LimitedApp app,
    int minutes,
  ) async {
    final choices = LimitedApp.minuteChoices.where((m) => m < minutes);
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('${app.name}: fewer minutes a day'),
        children: [
          for (final m in choices.toList().reversed)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, m),
              child: Text(m == 0 ? 'Blocked all day' : formatMinutes(m)),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    await _save(
      current,
      {app.id: picked},
      title: 'Make ${app.name} stricter?',
      message:
          '${formatMinutes(minutes)} → '
          '${picked == 0 ? 'blocked all day' : formatMinutes(picked)} a day. '
          'This can’t be undone.',
      confirmLabel: 'Make stricter',
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(appLimitsServiceProvider);
    final async = ref.watch(appLimitsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Daily app limits')),
      body: !service.isSupported
          ? const Center(child: Text('Available on Android'))
          : switch (async) {
              AsyncValue(:final value?) => _body(context, service, value),
              AsyncValue(:final error?) => Center(
                child: Text('Couldn’t read the limits: $error'),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
    );
  }

  Widget _body(
    BuildContext context,
    AppLimitsService service,
    AppLimitsState s,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Give the apps that eat your day a daily limit. Once locked, a '
            'limit can never be raised or removed — only made stricter. When '
            'the time is used up the app won’t open again until midnight.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        _Need(
          icon: Icons.query_stats_rounded,
          title: 'Usage access',
          ok: s.usageAccess,
          okText:
              'Sees which app is open, and when YouTube, YouTube Music or '
              'Spotify keeps playing in the background, to count its time',
          fixText:
              'Allow usage access for Redemption, to see which app is open and '
              'what plays in the background.',
          onFix: () => service.openSystemSetting('usageAccess'),
        ),
        _Need(
          icon: Icons.layers_outlined,
          title: 'Display over other apps',
          ok: s.overlay,
          okText: 'Covers an app whose time is used up',
          fixText:
              'Allow Redemption to display over other apps, to cover an app '
              'whose time is used up.',
          onFix: () => service.openSystemSetting('overlay'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'No accessibility service and no notification access are used, so '
            'Google Pay, banking apps and Play Protect are happy. A small '
            '“Keeping your limits” notification stays while limits are set.',
            style: muted,
          ),
        ),
        if (s.autoTime == false)
          _Need(
            icon: Icons.schedule_rounded,
            title: 'Automatic date & time',
            ok: false,
            okText: '',
            fixText:
                'Turn on “Set time automatically”, so the day’s limits '
                'can’t be reset by changing the clock.',
            onFix: () => service.openSystemSetting('dateTime'),
          ),
        const SectionHeader('Apps'),
        for (final app in LimitedApp.all)
          if (s.quotas[app.id] case final q?)
            _LockedTile(
              app: app,
              minutes: q,
              used: s.usedOf(app.id),
              onStricter: q > 0 && !_saving
                  ? () => _makeStricter(s, app, q)
                  : null,
            )
          else
            _DraftTile(
              app: app,
              minutes: _draft[app.id],
              onChanged: (m) => setState(() {
                if (m == null) {
                  _draft.remove(app.id);
                } else {
                  _draft[app.id] = m;
                }
              }),
            ),
        if (_draft.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: FilledButton.icon(
              onPressed: s.ready && !_saving ? () => _lockDraft(s) : null,
              icon: const Icon(Icons.lock_rounded),
              label: const Text('Lock limits'),
            ),
          ),
          if (!s.ready)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Allow the two permissions above first.',
                style: muted,
              ),
            ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Text(
            'Time counts while an app is on screen or playing in the '
            'background. Chrome pages opened inside other apps (sign-ins, '
            'payment checks) aren’t counted or blocked. Other browsers and '
            'apps aren’t limited. Switching the permissions above off would '
            'stop the limits — keeping them on is your promise to yourself.',
            style: muted,
          ),
        ),
      ],
    );
  }
}

class _LockedTile extends StatelessWidget {
  const _LockedTile({
    required this.app,
    required this.minutes,
    required this.used,
    required this.onStricter,
  });

  final LimitedApp app;
  final int minutes;
  final Duration used;
  final VoidCallback? onStricter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final usedMin = used.inMinutes;
    final usedUp = used >= Duration(minutes: minutes);
    final status = minutes == 0
        ? 'Blocked all day'
        : usedUp
        ? 'Used up — opens again after midnight'
        : '${formatMinutes(usedMin)} of ${formatMinutes(minutes)} used today';
    return ListTile(
      leading: Icon(
        usedUp ? Icons.block_rounded : Icons.lock_rounded,
        color: usedUp ? scheme.error : scheme.primary,
      ),
      title: Text(app.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status),
          if (minutes > 0) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (used.inSeconds / (minutes * 60)).clamp(0.0, 1.0),
              color: usedUp ? scheme.error : null,
            ),
          ],
        ],
      ),
      trailing: onStricter == null
          ? null
          : IconButton(
              tooltip: 'Make ${app.name} stricter',
              onPressed: onStricter,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({
    required this.app,
    required this.minutes,
    required this.onChanged,
  });

  final LimitedApp app;

  /// Null: not limited.
  final int? minutes;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    const choices = LimitedApp.minuteChoices;
    final m = minutes;
    final i = m == null ? -1 : choices.indexOf(m);
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.lock_open_rounded),
          title: Text(app.name),
          subtitle: Text(app.covers),
          value: m != null,
          onChanged: (on) => onChanged(on ? 30 : null),
        ),
        if (m != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    m == 0 ? 'Blocked all day' : '${formatMinutes(m)} a day',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Fewer minutes for ${app.name}',
                  onPressed: i > 0 ? () => onChanged(choices[i - 1]) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                IconButton(
                  tooltip: 'More minutes for ${app.name}',
                  onPressed: i < choices.length - 1
                      ? () => onChanged(choices[i + 1])
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Need extends StatelessWidget {
  const _Need({
    required this.icon,
    required this.title,
    required this.ok,
    required this.okText,
    required this.fixText,
    required this.onFix,
  });

  final IconData icon;
  final String title;
  final bool ok;
  final String okText;
  final String fixText;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(ok ? okText : fixText),
      trailing: ok
          ? Icon(Icons.check_circle_rounded, color: scheme.primary)
          : TextButton(onPressed: onFix, child: const Text('Fix')),
      onTap: ok ? null : onFix,
    );
  }
}
