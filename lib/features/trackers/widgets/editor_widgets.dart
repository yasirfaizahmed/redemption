import 'package:material_ui/material_ui.dart';

import '../../../app/theme/palette.dart';
import '../../../core/widgets/tracker_icons.dart';
import '../../../domain/models.dart';
import '../../../domain/tracker_type.dart';

/// Grid of all input types with an example for each.
class TypePickerGrid extends StatelessWidget {
  const TypePickerGrid({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final TrackerType? selected;
  final ValueChanged<TrackerType> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 560 ? 3 : 2;
        final w = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final t in TrackerType.values)
              SizedBox(
                width: w,
                child: Semantics(
                  button: true,
                  selected: t == selected,
                  child: Material(
                    color: t == selected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => onSelected(t),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(t.icon, color: theme.colorScheme.primary),
                            const SizedBox(height: 8),
                            Text(t.label, style: theme.textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              t.example,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

Future<String?> showIconPicker(
  BuildContext context, {
  required String current,
  required Color color,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.7,
    maxChildSize: 0.95,
    builder: (context, controller) {
      final theme = Theme.of(context);
      return ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text('Choose an icon', style: theme.textTheme.titleLarge),
          for (final category in TrackerIcons.categories.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(category.key, style: theme.textTheme.titleSmall),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in category.value.entries)
                  Tooltip(
                    message: e.key,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(context, e.key),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: e.key == current
                              ? color
                              : color.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          e.value,
                          color: e.key == current ? Colors.white : color,
                          semanticLabel: e.key,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      );
    },
  ),
);

class ColorSwatches extends StatelessWidget {
  const ColorSwatches({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final c in Palette.trackerColors)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                selected: c == selected,
                label: 'Colour',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onSelected(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: c == selected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 3,
                            )
                          : null,
                    ),
                    child: c == selected
                        ? const Icon(Icons.check_rounded, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class WeekdayPicker extends StatelessWidget {
  const WeekdayPicker({super.key, required this.mask, required this.onChanged});

  final int mask;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var d = 1; d <= 7; d++)
              Semantics(
                button: true,
                selected: Weekdays.has(mask, d),
                label: Weekdays.names[d - 1],
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    final next = Weekdays.toggle(mask, d);
                    if (next != 0) onChanged(next);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Weekdays.has(mask, d)
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                    ),
                    child: Text(
                      Weekdays.labels[d - 1],
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Weekdays.has(mask, d)
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final (label, value) in const [
              ('Every day', Weekdays.all),
              ('Weekdays', Weekdays.workweek),
              ('Weekends', 0x60),
            ])
              ChoiceChip(
                label: Text(label),
                selected: mask == value,
                onSelected: (_) => onChanged(value),
              ),
          ],
        ),
      ],
    );
  }
}
