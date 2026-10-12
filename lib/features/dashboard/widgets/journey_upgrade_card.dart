import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/common.dart';
import '../../../domain/journey_upgrades.dart';
import '../../../state/providers.dart';

final _log = Logger('Upgrade');

final journeyUpgradeProvider = Provider<JourneyUpgrade>(
  (ref) => JourneyUpgrade.plan(ref.watch(activeTrackersProvider)),
);

/// Offers new template improvements to an existing journey, once.
class JourneyUpgradeCard extends ConsumerStatefulWidget {
  const JourneyUpgradeCard({super.key});

  @override
  ConsumerState<JourneyUpgradeCard> createState() => _JourneyUpgradeCardState();
}

class _JourneyUpgradeCardState extends ConsumerState<JourneyUpgradeCard> {
  bool _busy = false;

  Future<void> _remember() async {
    final repo = ref.read(settingsRepositoryProvider);
    final s = await repo.load();
    await repo.save(
      s.copyWith(
        dismissedUpgrades: {...s.dismissedUpgrades, JourneyUpgrade.id},
      ),
    );
  }

  Future<void> _apply(JourneyUpgrade upgrade) async {
    final journey = ref.read(activeJourneyProvider).value;
    if (journey == null) return;
    setState(() => _busy = true);
    try {
      final trackers = ref.read(trackerRepositoryProvider);
      for (final p in upgrade.prayersWithRule()) {
        await trackers.update(p);
      }
      for (final t in upgrade.newMealChecks(
        journeyId: journey.id,
        from: ref.read(todayProvider),
      )) {
        await trackers.insert(t);
      }
      await _remember();
      _log.info(
        'Applied journey upgrade: ${upgrade.prayers.length} prayers, '
        '${upgrade.meals.length} meal checks',
      );
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
    final dismissed = ref.watch(
      settingsValueProvider.select(
        (s) => s.dismissedUpgrades.contains(JourneyUpgrade.id),
      ),
    );
    final upgrade = ref.watch(journeyUpgradeProvider);
    if (dismissed || upgrade.isEmpty) return const SizedBox.shrink();

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
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : _remember,
                    child: const Text('Not now'),
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
