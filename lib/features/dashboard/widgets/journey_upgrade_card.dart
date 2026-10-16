import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/common.dart';
import '../../../data/repositories/upgrade_repository.dart';
import '../../../domain/journey_upgrades.dart';
import '../../../state/providers.dart';

final _log = Logger('Upgrade');

final journeyUpgradeProvider = Provider<JourneyUpgrade>(
  (ref) => JourneyUpgrade.plan(
    ref.watch(allTrackersProvider).value ?? const [],
    dismissed: ref.watch(
      settingsValueProvider.select((s) => s.dismissedUpgrades),
    ),
  ),
);

/// Offers new template improvements to an existing journey, once each.
class JourneyUpgradeCard extends ConsumerStatefulWidget {
  const JourneyUpgradeCard({super.key});

  @override
  ConsumerState<JourneyUpgradeCard> createState() => _JourneyUpgradeCardState();
}

class _JourneyUpgradeCardState extends ConsumerState<JourneyUpgradeCard> {
  bool _busy = false;

  Future<void> _remember(Set<String> ids) async {
    final repo = ref.read(settingsRepositoryProvider);
    final s = await repo.load();
    await repo.save(
      s.copyWith(dismissedUpgrades: {...s.dismissedUpgrades, ...ids}),
    );
  }

  Future<void> _apply(JourneyUpgrade upgrade) async {
    final journey = ref.read(activeJourneyProvider).value;
    if (journey == null) return;
    setState(() => _busy = true);
    try {
      await UpgradeRepository(
        ref.read(databaseProvider),
      ).apply(upgrade, journeyId: journey.id, today: ref.read(todayProvider));
      await _remember(upgrade.ids);
      _log.info('Applied journey upgrade ${upgrade.ids}');
      if (mounted) showSnack(context, 'Added to your journey — see Today.');
    } catch (e, s) {
      _log.severe('Journey upgrade failed', e, s);
      if (mounted) showSnack(context, 'Couldn’t update the journey: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final upgrade = ref.watch(journeyUpgradeProvider);
    if (upgrade.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    String list(Iterable<String> names) {
      final l = names.toList();
      return l.length <= 1
          ? l.join()
          : '${l.sublist(0, l.length - 1).join(', ')} & ${l.last}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'New for your journey',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (upgrade.prayers.isNotEmpty)
                _Point(
                  icon: Icons.business_center_outlined,
                  text:
                      'Office days: ${list(upgrade.prayers.map((p) => p.name))} '
                      '— no masjid, so the congregation button steps aside '
                      'and praying on time earns full marks.',
                ),
              if (upgrade.meals.isNotEmpty)
                _Point(
                  icon: Icons.schedule_rounded,
                  text:
                      '“On time?” checks for '
                      '${list(upgrade.meals.map((m) => m.$2))} that count '
                      'towards your score (from today, past days unchanged).',
                ),
              if (upgrade.workout != null)
                const _Point(
                  icon: Icons.fitness_center_rounded,
                  text:
                      'Workout becomes “Did you train?”: Trained earns the '
                      'points, with a comment for what you did. What you '
                      'already wrote moves into the comments.',
                ),
              if (upgrade.mealTexts.isNotEmpty)
                const _Point(
                  icon: Icons.restaurant_rounded,
                  text:
                      'Meals: the “on time?” checks ask “What did you eat?” '
                      '(just for your notes). Only eating on time earns '
                      'points; the separate meal entries stop counting from '
                      'today and keep their history.',
                ),
              if (upgrade.hasLeftOfficeSkip)
                _Point(
                  icon: Icons.home_work_outlined,
                  text:
                      '${upgrade.leftOffice!.name}: switches itself off when '
                      'you work from home'
                      '${upgrade.leftOfficeSkip!.whenOptionIds.contains('leave') ? ' or are on leave' : ''}'
                      ' — no reminder, and those days leave it out of your '
                      'score, past ones included (whether or not you logged '
                      'it).',
                ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => _remember(upgrade.ids),
                    child: const Text('No thanks'),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : () => _apply(upgrade),
                    child: const Text('Add to my journey'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSecondaryContainer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
