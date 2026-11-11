import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/time/time_of_day_x.dart';
import '../../domain/app_settings.dart';
import '../../domain/math_challenge.dart';
import '../../services/wake_alarm_service.dart';
import '../../state/providers.dart';

/// Source of the sums' numbers (fixed in tests).
final alarmRandomProvider = Provider<Random>((ref) => Random());

/// Puts [AlarmRingScreen] over the whole app while a wake-up alarm rings —
/// above every route, sheet and dialog, whatever the app was showing — and
/// makes sure neither the Back button nor the back gesture gets past it.
class AlarmRingGate extends ConsumerStatefulWidget {
  const AlarmRingGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AlarmRingGate> createState() => _AlarmRingGateState();
}

class _AlarmRingGateState extends ConsumerState<AlarmRingGate> {
  /// What the app's navigator last said about handling Back, to hand back
  /// once the alarm is solved.
  bool _navigatorHandlesBack = false;

  /// While covered, the system always sends Back to the app (where it is
  /// swallowed): whatever the navigator says is kept for later instead.
  bool _onNavigation(NavigationNotification n, bool covered) {
    _navigatorHandlesBack = n.canHandlePop;
    if (!covered) return false;
    if (!n.canHandlePop) {
      const NavigationNotification(canHandlePop: true).dispatch(context);
    }
    return !n.canHandlePop;
  }

  @override
  Widget build(BuildContext context) {
    final ringing =
        ref.watch(ringingWakeAlarmsProvider).value ?? const <WakeAlarm>[];
    final covered = ringing.isNotEmpty;
    ref.listen(ringingWakeAlarmsProvider, (previous, next) {
      final was = previous?.value?.isNotEmpty ?? false;
      final now = next.value?.isNotEmpty ?? false;
      if (was == now) return;
      NavigationNotification(canHandlePop: now || _navigatorHandlesBack)
          .dispatch(context);
      if (!now) ref.read(wakeAlarmServiceProvider).ringingEnded();
    });
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Always the same wrappers, so the app underneath keeps its state.
        NotificationListener<NavigationNotification>(
          onNotification: (n) => _onNavigation(n, covered),
          // While ringing, pages underneath lose their back gesture (it
          // would pop them behind the sums); Back itself is swallowed by
          // the app's back button dispatcher.
          child: Theme(
            data: covered
                ? theme.copyWith(
                    pageTransitionsTheme: const PageTransitionsTheme(
                      builders: {
                        TargetPlatform.android:
                            FadeForwardsPageTransitionsBuilder(),
                      },
                    ),
                  )
                : theme,
            child: IgnorePointer(
              ignoring: covered,
              child: ExcludeSemantics(excluding: covered, child: widget.child),
            ),
          ),
        ),
        // A different set of alarms gets fresh sums (and never a stuck
        // "stopping" screen for an alarm that took over).
        if (covered)
          AlarmRingScreen(
            key: ValueKey(ringing.map((a) => a.id).join(',')),
            alarms: ringing,
          ),
      ],
    );
  }
}

/// The alarm is ringing: it stops only when the sums are solved.
class AlarmRingScreen extends ConsumerStatefulWidget {
  const AlarmRingScreen({super.key, required this.alarms});

  /// The alarms ringing now (all are stopped together).
  final List<WakeAlarm> alarms;

  @override
  ConsumerState<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends ConsumerState<AlarmRingScreen> {
  static const _maxDigits = 7;

  late final List<MathProblem> _problems;
  int _index = 0;
  String _typed = '';
  bool _wrong = false;
  bool _stopping = false;
  bool _stopFailed = false;

  @override
  void initState() {
    super.initState();
    // Only now, with sums to solve, may the alarm guard hold the phone.
    ref.read(wakeAlarmServiceProvider).sumsShown();
    final settings = ref.read(settingsValueProvider);
    _problems = MathChallenge.generateAll(
      ref.read(alarmRandomProvider),
      settings.alarmMathDifficulty,
      settings.alarmMathCount,
    );
  }

  bool get _solved => _index >= _problems.length;

  void _press(String digit) {
    if (_stopping || _solved || _typed.length >= _maxDigits) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _typed += digit;
      _wrong = false;
    });
  }

  void _backspace() {
    if (_typed.isEmpty) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _typed = _typed.substring(0, _typed.length - 1));
  }

  Future<void> _submit() async {
    if (_stopping || _typed.isEmpty) return;
    if (!_solved && !_problems[_index].isSolvedBy(_typed)) {
      unawaited(HapticFeedback.heavyImpact());
      setState(() {
        _typed = '';
        _wrong = true;
      });
      return;
    }
    setState(() {
      _index++;
      _typed = '';
      _wrong = false;
    });
    if (_solved) await _stop();
  }

  Future<void> _stop() async {
    setState(() {
      _stopping = true;
      _stopFailed = false;
    });
    final service = ref.read(wakeAlarmServiceProvider);
    var ok = true;
    for (final alarm in widget.alarms) {
      ok = await service.stop(alarm.id) && ok;
    }
    // On success the gate removes this screen as the alarm stops ringing.
    if (mounted) {
      setState(() {
        _stopping = false;
        _stopFailed = !ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(settingsValueProvider);
    final now = ref.watch(clockProvider);
    final label = widget.alarms
        .map((a) => a.label)
        .where((l) => l.isNotEmpty)
        .toSet()
        .join(' · ');

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            // The keypad stays put at the bottom; only the top scrolls, and
            // on a short screen the dua makes room for the sum.
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(
                            time: Clock.format(
                              Clock.fromDateTime(now),
                              use24h: settings.use24h,
                            ),
                            label: label,
                            showDua:
                                settings.quotePack != QuotePack.discipline &&
                                constraints.maxHeight >= 640,
                          ),
                          const SizedBox(height: 12),
                          if (_solved)
                            _Stopping(failed: _stopFailed, onRetry: _stop)
                          else
                            _ProblemCard(
                              problem: _problems[_index],
                              number: _index + 1,
                              total: _problems.length,
                              typed: _typed,
                              wrong: _wrong,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!_solved) ...[
                    const SizedBox(height: 12),
                    _Keypad(
                      onDigit: _press,
                      onBackspace: _backspace,
                      onSubmit: _submit,
                      canSubmit: _typed.isNotEmpty && !_stopping,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.time,
    required this.label,
    required this.showDua,
  });

  final String time;
  final String label;
  final bool showDua;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    return Column(
      children: [
        Icon(Icons.alarm_on_rounded, size: 40, color: scheme.primary),
        const SizedBox(height: 4),
        Text(
          time,
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text('Time to wake up', style: theme.textTheme.titleMedium),
        if (label.isNotEmpty)
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        if (showDua) ...[
          const SizedBox(height: 8),
          Text(
            '“Alḥamdu lillāhil-ladhī aḥyānā baʿda mā amātanā wa ilayhin-nushūr” '
            '— All praise is for Allah, who gave us life after taking it from '
            'us, and to Him is the resurrection. (al-Bukhārī)',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({
    required this.problem,
    required this.number,
    required this.total,
    required this.typed,
    required this.wrong,
  });

  final MathProblem problem;
  final int number;
  final int total;
  final String typed;
  final bool wrong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: [
            Text(
              total == 1
                  ? 'Solve this to stop the alarm'
                  : 'Solve to stop the alarm · $number of $total',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${problem.text} = ?',
                maxLines: 1,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              label: typed.isEmpty
                  ? 'Your answer, empty'
                  : 'Your answer $typed',
              excludeSemantics: true,
              child: Container(
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: wrong ? scheme.error : scheme.outlineVariant,
                    width: wrong ? 2 : 1,
                  ),
                ),
                child: Text(
                  typed.isEmpty
                      ? (wrong ? 'Not right — try again' : '…')
                      : typed,
                  style: typed.isEmpty
                      ? theme.textTheme.bodyLarge?.copyWith(
                          color: wrong ? scheme.error : scheme.onSurfaceVariant,
                        )
                      : theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Digits, backspace and OK — its own keys, so nothing depends on the
/// system keyboard over the lock screen.
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    required this.canSubmit,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final bool canSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget key(
      Widget child,
      VoidCallback? onTap, {
      Color? color,
      String? label,
    }) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: label != null,
          child: Material(
            color: color ?? scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(height: 60, child: Center(child: child)),
            ),
          ),
        ),
      ),
    );
    Widget digit(String d) => key(
      Text(
        d,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      () => onDigit(d),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final d in row) digit(d)]),
        Row(
          children: [
            key(
              const Icon(Icons.backspace_outlined),
              onBackspace,
              label: 'Delete',
            ),
            digit('0'),
            key(
              Icon(
                Icons.check_rounded,
                color: canSubmit ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
              canSubmit ? onSubmit : null,
              color: canSubmit ? scheme.primary : null,
              label: 'Check answer',
            ),
          ],
        ),
      ],
    );
  }
}

class _Stopping extends StatelessWidget {
  const _Stopping({required this.failed, required this.onRetry});
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          if (!failed) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Solved — stopping the alarm…',
              style: theme.textTheme.titleMedium,
            ),
          ] else ...[
            Text(
              'Solved, but the alarm didn’t stop.',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Stop the alarm'),
            ),
          ],
        ],
      ),
    );
  }
}
