import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/time/day.dart';

/// Shared "length of the journey" control: presets + fine slider.
class DurationPicker extends StatelessWidget {
  const DurationPicker({
    super.key,
    required this.days,
    required this.onChanged,
  });

  final int days;
  final ValueChanged<int> onChanged;

  static const presets = [21, 40, 66, 90, 100, 180, 365];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$days', style: theme.textTheme.displaySmall),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('days', style: theme.textTheme.titleMedium),
            ),
            const Spacer(),
            if (days == 90)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Recommended',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        Slider(
          value: days.toDouble().clamp(7, 365),
          min: 7,
          max: 365,
          divisions: 358,
          label: '$days days',
          onChanged: (v) => onChanged(v.round()),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in presets)
              ChoiceChip(
                label: Text('$p'),
                selected: days == p,
                onSelected: (_) => onChanged(p),
              ),
          ],
        ),
      ],
    );
  }
}

/// Start-date selector with Today / Tomorrow shortcuts.
class StartDayPicker extends StatelessWidget {
  const StartDayPicker({
    super.key,
    required this.day,
    required this.today,
    required this.onChanged,
  });

  final Day day;
  final Day today;
  final ValueChanged<Day> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('Today'),
          selected: day == today,
          onSelected: (_) => onChanged(today),
        ),
        ChoiceChip(
          label: const Text('Tomorrow'),
          selected: day == today.addDays(1),
          onSelected: (_) => onChanged(today.addDays(1)),
        ),
        ActionChip(
          avatar: const Icon(Icons.calendar_month_rounded, size: 18),
          label: Text(
            day == today || day == today.addDays(1)
                ? 'Pick a date'
                : DateFormat('d MMM yyyy').format(day.toDateTime()),
          ),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: day.toDateTime(),
              firstDate: today.addDays(-365).toDateTime(),
              lastDate: today.addDays(365).toDateTime(),
            );
            if (picked != null) onChanged(Day.fromDateTime(picked));
          },
        ),
      ],
    );
  }
}
