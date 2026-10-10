import 'package:material_ui/material_ui.dart';

import '../../core/widgets/common.dart';
import '../../domain/neuro_phase.dart';
import '../../domain/quotes.dart';

/// The motto and the science behind the 90 days.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final TextStyle? body = theme.textTheme.bodyLarge?.copyWith(height: 1.5);
    return Scaffold(
      appBar: AppBar(title: const Text('The science')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            'REDEMPTION',
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 6,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Do the hard thing. Again. Until it’s who you are.',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Your brain is plastic: the connections you use get stronger, the ones '
            'you neglect fade. A habit is a well-worn pathway. Rewiring is simply '
            'walking a new path often enough that it becomes the default — and '
            'leaving the old one alone long enough for it to grow over.',
            style: body,
          ),
          const SectionHeader(
            'How it works',
            padding: EdgeInsets.fromLTRB(0, 28, 0, 8),
          ),
          const _Point(
            icon: Icons.bolt_rounded,
            title: 'Hebbian learning',
            text:
                '“Neurons that fire together wire together.” Each repetition strengthens '
                'the synapses behind a behaviour; myelin insulates well-used circuits so '
                'they fire faster and with less effort.',
          ),
          const _Point(
            icon: Icons.timeline_rounded,
            title: '66 days, on average',
            text:
                'In a UCL study (Lally et al., 2010) it took a median of 66 days for a daily '
                'behaviour to become automatic — ranging from 18 to 254 days. 90 days gives '
                'you the median plus a margin to lock it in.',
          ),
          const _Point(
            icon: Icons.replay_rounded,
            title: 'Never miss twice',
            text:
                'The same study found a single missed day did not derail habit formation. '
                'What matters is getting straight back on track — which is why streaks here '
                'never break on an unfinished “today”.',
          ),
          const _Point(
            icon: Icons.checklist_rounded,
            title: 'Make it obvious, make it easy',
            text:
                'Planned times, one-tap logging, reminders and a visible scoreboard reduce '
                'friction and give your brain the feedback loop it needs.',
          ),
          const SectionHeader(
            'The three phases',
            padding: EdgeInsets.fromLTRB(0, 28, 0, 8),
          ),
          for (final k in NeuroPhaseKind.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${k.title} · ${k.tagline}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    k.description,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          const SectionHeader(
            'Reminders',
            padding: EdgeInsets.fromLTRB(0, 20, 0, 8),
          ),
          for (final q in Quotes.faith.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '“${q.text}”',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                    TextSpan(
                      text: '  — ${q.source}',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Private by design: all data lives on your device. Built with Flutter, '
            'so the same codebase runs on Android and iOS.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
