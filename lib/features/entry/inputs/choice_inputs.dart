import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/palette.dart';
import '../../../domain/models.dart';
import '../../../domain/tracker_config.dart';
import '../../../domain/tracker_value.dart';

/// Two large, thumb-friendly tiles: Yes / No.
class CheckboxInput extends StatelessWidget {
  const CheckboxInput({
    super.key,
    required this.tracker,
    required this.value,
    required this.onChanged,
  });

  final Tracker tracker;
  final TrackerValue? value;
  final ValueChanged<TrackerValue?> onChanged;

  @override
  Widget build(BuildContext context) {
    final win = tracker.winAnswer;
    final current = value is BoolValue ? (value! as BoolValue).value : null;
    Widget tile(bool answer) => Expanded(
      child: BigChoiceTile(
        label: answer ? tracker.config.yesLabel : tracker.config.noLabel,
        icon: Palette.iconForAnswer(answer),
        // Green for the winning answer, red for the other — whichever it is.
        color: answer == win ? Palette.success : Palette.failure,
        selected: current == answer,
        onTap: () => onChanged(BoolValue(answer)),
      ),
    );
    // The winning answer always comes first.
    return Row(children: [tile(win), const SizedBox(width: 12), tile(!win)]);
  }
}

class BigChoiceTile extends StatelessWidget {
  const BigChoiceTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 128,
        decoration: BoxDecoration(
          color: selected
              ? color
              : color.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.14 : 0.08,
                ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: selected ? Colors.white : color),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: selected
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A vertical list of large option tiles; each shows the credit it earns.
class SingleChoiceInput extends StatelessWidget {
  const SingleChoiceInput({
    super.key,
    required this.tracker,
    required this.value,
    required this.onChanged,
  });

  final Tracker tracker;
  final TrackerValue? value;
  final ValueChanged<TrackerValue?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = tracker.config.options;
    final selected = value is ChoiceValue
        ? (value! as ChoiceValue).optionId
        : null;
    final showCredit = options.any((o) => o.score < 1);
    if (options.isEmpty) {
      return const Text('No options yet — add some in the tracker editor.');
    }
    return Column(
      children: [
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OptionTile(
              option: o,
              selected: o.id == selected,
              showCredit: showCredit,
              onTap: () => onChanged(ChoiceValue(o.id)),
            ),
          ),
      ],
    );
  }
}

class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
    this.showCredit = false,
  });

  final ChoiceOption option;
  final bool selected;
  final bool showCredit;
  final VoidCallback onTap;

  static Color creditColor(double score) => score >= 1
      ? Palette.success
      : score > 0
      ? Palette.partial
      : Palette.failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = showCredit ? creditColor(option.score) : scheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.16)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: option.emoji.isNotEmpty
                          ? Text(
                              option.emoji,
                              style: const TextStyle(fontSize: 24),
                            )
                          : Icon(
                              selected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: selected ? accent : scheme.outline,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option.label,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (showCredit)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: creditColor(option.score)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(option.score * 100).round()}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: creditColor(option.score),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    AnimatedOpacity(
                      opacity: selected ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(Icons.check_circle_rounded, color: accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrap of filter chips. New options can be created inline.
class MultiChoiceInput extends StatelessWidget {
  const MultiChoiceInput({
    super.key,
    required this.tracker,
    required this.value,
    required this.onChanged,
    required this.onAddOption,
  });

  final Tracker tracker;
  final TrackerValue? value;
  final ValueChanged<TrackerValue?> onChanged;

  /// Persists a new option on the tracker.
  final Future<void> Function(ChoiceOption option) onAddOption;

  List<String> get _selected => value is MultiChoiceValue
      ? (value! as MultiChoiceValue).optionIds
      : const [];

  Future<void> _add(BuildContext context) async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New option'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Oats'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    final text = label?.trim() ?? '';
    if (text.isEmpty) return;
    final option = ChoiceOption(
      id: 'o${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      label: text,
    );
    await onAddOption(option);
    onChanged(MultiChoiceValue([..._selected, option.id]));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in tracker.config.options)
          FilterChip(
            label: Text(o.display),
            selected: selected.contains(o.id),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            onSelected: (on) {
              HapticFeedback.selectionClick();
              final next = [...selected];
              on ? next.add(o.id) : next.remove(o.id);
              onChanged(next.isEmpty ? null : MultiChoiceValue(next));
            },
          ),
        if (tracker.config.allowCustomOptions)
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            onPressed: () => _add(context),
          ),
      ],
    );
  }
}
