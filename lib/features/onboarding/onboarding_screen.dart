import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/time/day.dart';
import '../../core/time/time_of_day_x.dart';
import '../../core/widgets/tracker_icons.dart';
import '../../domain/neuro_phase.dart';
import '../../domain/templates.dart';
import '../../state/drive_sync.dart';
import '../../state/providers.dart';
import '../journey/journey_form.dart';
import '../settings/drive_backup.dart';

/// First-run flow: the why → pick a template → shape the journey.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  JourneyTemplate _template = Templates.redemption;
  final _name = TextEditingController(text: Templates.redemption.suggestedName);
  final _intention = TextEditingController(
    text: Templates.redemption.suggestedIntention,
  );
  int _days = 90;
  Day? _start;
  int _dayStart = 180;
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    _intention.dispose();
    super.dispose();
  }

  void _go(int page) {
    FocusScope.of(context).unfocus();
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _pickTemplate(JourneyTemplate t) => setState(() {
    _template = t;
    _name.text = t.suggestedName;
    _intention.text = t.suggestedIntention;
  });

  Future<void> _finish() async {
    setState(() => _busy = true);
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final settings = await settingsRepo.load();
    await settingsRepo.save(
      settings.copyWith(onboardingDone: true, dayStartMinutes: _dayStart),
    );
    final today = Day.current(dayStartMinutes: _dayStart);
    await ref
        .read(journeyRepositoryProvider)
        .createFromTemplate(
          template: _template,
          name: _name.text,
          intention: _intention.text,
          startDay: _start ?? today,
          durationDays: _days,
        );
    await ref.read(notificationServiceProvider).requestPermission();
    // The router redirects to the dashboard as soon as the journey exists.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 4,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: i <= _page
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _WelcomePage(
                    onNext: () => _go(1),
                    onRestore: ref.watch(driveAuthProvider).isSupported
                        ? () => connectGoogleDrive(
                            context,
                            ref,
                            freshInstall: true,
                          )
                        : null,
                    restoring: ref.watch(driveSyncProvider).busy,
                  ),
                  _TemplatePage(
                    selected: _template,
                    onSelected: _pickTemplate,
                    onBack: () => _go(0),
                    onNext: () => _go(2),
                  ),
                  _SetupPage(
                    name: _name,
                    intention: _intention,
                    days: _days,
                    onDays: (d) => setState(() => _days = d),
                    start: _start ?? Day.current(dayStartMinutes: _dayStart),
                    today: Day.current(dayStartMinutes: _dayStart),
                    onStart: (d) => setState(() => _start = d),
                    dayStart: _dayStart,
                    onDayStart: (m) => setState(() => _dayStart = m),
                    busy: _busy,
                    finishLabel: _template.id == Templates.redemption.id
                        ? 'Bismillah — begin'
                        : 'Begin the journey',
                    onBack: () => _go(1),
                    onFinish: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({
    required this.onNext,
    required this.onRestore,
    required this.restoring,
  });
  final VoidCallback onNext;

  /// Reinstalled? Bring the journey back from Google Drive. Null when Drive
  /// backup isn't available on this device.
  final VoidCallback? onRestore;
  final bool restoring;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [
              Icon(Icons.auto_awesome_rounded, size: 44, color: scheme.primary),
              const SizedBox(height: 20),
              Text(
                'REDEMPTION',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 6,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Rewire your brain\nin 90 days.',
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: 16),
              Text(
                'Every time you do the hard thing, a new neural pathway gets a little '
                'stronger — and the old one a little weaker. Repeat it long enough and '
                'the hard thing becomes who you are.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              for (final (i, k) in NeuroPhaseKind.values.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          '${i + 1}',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${k.title} — ${k.tagline}',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              switch (k) {
                                NeuroPhaseKind.uproot => 'Days 1–21. Resistance is loudest. Show up anyway.',
                                NeuroPhaseKind.rewire =>
                                  'Days 22–66. Repetition builds the new road.',
                                NeuroPhaseKind.redeem =>
                                  'Days 67–90. It becomes automatic. Own it.',
                              },
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, onRestore == null ? 16 : 4),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: restoring ? null : onNext,
              child: const Text('Let’s build it'),
            ),
          ),
        ),
        if (onRestore != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: restoring ? null : onRestore,
                icon: restoring
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download_outlined),
                label: Text(
                  restoring
                      ? 'Bringing your journey back…'
                      : 'Restore from Google Drive',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TemplatePage extends StatelessWidget {
  const _TemplatePage({
    required this.selected,
    required this.onSelected,
    required this.onBack,
    required this.onNext,
  });

  final JourneyTemplate selected;
  final ValueChanged<JourneyTemplate> onSelected;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            children: [
              Text(
                'Start from a template',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Everything is editable later — add, remove or reshape any tracker.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              for (final t in Templates.all)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Semantics(
                    button: true,
                    selected: t == selected,
                    child: Material(
                      color: t == selected
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => onSelected(t),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(t.icon, color: scheme.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      t.name,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ),
                                  if (t == selected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: scheme.primary,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(t.tagline, style: theme.textTheme.bodySmall),
                              if (t.trackers.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final tt in t.trackers)
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        avatar: Icon(
                                          TrackerIcons.resolve(tt.tracker.icon),
                                          size: 16,
                                          color: Color(tt.tracker.color),
                                        ),
                                        label: Text(tt.tracker.name),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _NavBar(onBack: onBack, onNext: onNext, nextLabel: 'Continue'),
      ],
    );
  }
}

class _SetupPage extends StatelessWidget {
  const _SetupPage({
    required this.name,
    required this.intention,
    required this.days,
    required this.onDays,
    required this.start,
    required this.today,
    required this.onStart,
    required this.dayStart,
    required this.onDayStart,
    required this.busy,
    required this.finishLabel,
    required this.onBack,
    required this.onFinish,
  });

  final TextEditingController name;
  final TextEditingController intention;
  final int days;
  final ValueChanged<int> onDays;
  final Day start;
  final Day today;
  final ValueChanged<Day> onStart;
  final int dayStart;
  final ValueChanged<int> onDayStart;
  final bool busy;
  final String finishLabel;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            children: [
              Text('Shape your journey', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: intention,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Your intention (niyyah) — your “why”',
                  helperText: 'Shown on your dashboard as a daily reminder.',
                ),
              ),
              const SizedBox(height: 24),
              Text('How many days?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              DurationPicker(days: days, onChanged: onDays),
              const SizedBox(height: 24),
              Text('Start', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              StartDayPicker(day: start, today: today, onChanged: onStart),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.nights_stay_outlined),
                title: const Text('My day starts at'),
                subtitle: Text(
                  '${Clock.format(dayStart)} — anything logged before this (like a late '
                  'bedtime) counts for the previous day.',
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: Clock.toTimeOfDay(dayStart),
                  );
                  if (picked != null) onDayStart(Clock.fromTimeOfDay(picked));
                },
              ),
            ],
          ),
        ),
        _NavBar(
          onBack: onBack,
          onNext: busy ? null : onFinish,
          nextLabel: finishLabel,
        ),
      ],
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.onBack,
    required this.onNext,
    required this.nextLabel,
  });

  final VoidCallback onBack;
  final VoidCallback? onNext;
  final String nextLabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
    child: Row(
      children: [
        TextButton(onPressed: onBack, child: const Text('Back')),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(onPressed: onNext, child: Text(nextLabel)),
        ),
      ],
    ),
  );
}
