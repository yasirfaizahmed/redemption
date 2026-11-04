import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/achievements.dart';
import '../../domain/app_settings.dart';
import '../../state/providers.dart';

/// Saves the journey grid's tile settings from [edited] (the rest of the
/// settings are reloaded, so nothing else is overwritten).
Future<void> saveGridSettings(WidgetRef ref, AppSettings edited) async {
  final repo = ref.read(settingsRepositoryProvider);
  final s = await repo.load();
  await repo.save(
    s.copyWith(
      gridHiddenAchievements: edited.gridHiddenAchievements,
      gridEmojisPerTile: edited.gridEmojisPerTile,
      gridCompactPerfect: edited.gridCompactPerfect,
    ),
  );
}

/// The tile settings on their own (Insights grid).
Future<void> showGridSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => const _GridSettingsSheet(),
    );

class _GridSettingsSheet extends ConsumerStatefulWidget {
  const _GridSettingsSheet();

  @override
  ConsumerState<_GridSettingsSheet> createState() => _GridSettingsSheetState();
}

class _GridSettingsSheetState extends ConsumerState<_GridSettingsSheet> {
  late AppSettings _edited = ref.read(settingsValueProvider);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Journey grid', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          GridAchievementSettings(
            settings: _edited,
            onChanged: (s) => setState(() => _edited = s),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              await saveGridSettings(ref, _edited);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// Which achievements the journey grid's tiles show, how many fit on a
/// tile, and whether a perfect day's star stands for what it covers.
class GridAchievementSettings extends ConsumerWidget {
  const GridAchievementSettings({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final hidden = settings.gridHiddenAchievements;
    final choices = Achievements.choices(ref.watch(activeTrackersProvider));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Achievements on the tiles', style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          'Tap to show or hide. Tapping a day always lists everything it '
          'earned.',
          style: muted,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final c in choices)
              FilterChip(
                label: Text('${c.emoji}  ${c.label}'),
                selected: !hidden.contains(c.key),
                onSelected: (on) => onChanged(
                  settings.copyWith(
                    gridHiddenAchievements: on
                        ? ({...hidden}..remove(c.key))
                        : {...hidden, c.key},
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Emojis per tile', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (var n = 1; n <= Achievements.maxPerTile; n++)
              ButtonSegment(value: n, label: Text('$n')),
          ],
          selected: {settings.gridEmojisPerTile},
          onSelectionChanged: (s) =>
              onChanged(settings.copyWith(gridEmojisPerTile: s.first)),
        ),
        const SizedBox(height: 4),
        Text(
          'More than three sit in two tiny rows; the smallest tiles fit four.',
          style: muted,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Perfect days show just 🌟'),
          subtitle: const Text(
            'The star stands for every goal met; 🔥, 🕌 and optional trackers '
            'still show',
          ),
          value: settings.gridCompactPerfect,
          onChanged: (v) => onChanged(settings.copyWith(gridCompactPerfect: v)),
        ),
      ],
    );
  }
}
