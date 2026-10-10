import 'package:material_ui/material_ui.dart';

import '../../../domain/models.dart';
import '../../../domain/tracker_config.dart';
import '../../../domain/tracker_type.dart';
import '../../../domain/tracker_value.dart';
import 'attachment_input.dart';
import 'choice_inputs.dart';
import 'number_inputs.dart';
import 'text_input.dart';
import 'time_inputs.dart';

/// Picks the right input widget for a tracker type.
class TrackerInput extends StatelessWidget {
  const TrackerInput({
    super.key,
    required this.tracker,
    required this.value,
    required this.onChanged,
    required this.use24h,
    this.suggestions = const [],
    this.previousText,
    this.lastNumber,
    this.onAddOption,
  });

  final Tracker tracker;
  final TrackerValue? value;
  final ValueChanged<TrackerValue?> onChanged;
  final bool use24h;
  final List<String> suggestions;
  final String? previousText;
  final double? lastNumber;
  final Future<void> Function(ChoiceOption option)? onAddOption;

  @override
  Widget build(BuildContext context) => switch (tracker.type) {
    TrackerType.checkbox => CheckboxInput(
      tracker: tracker,
      value: value,
      onChanged: onChanged,
    ),
    TrackerType.singleChoice => SingleChoiceInput(
      tracker: tracker,
      value: value,
      onChanged: onChanged,
    ),
    TrackerType.multiChoice => MultiChoiceInput(
      tracker: tracker,
      value: value,
      onChanged: onChanged,
      onAddOption: onAddOption ?? (_) async {},
    ),
    TrackerType.time => TimeInput(
      tracker: tracker,
      value: value,
      onChanged: onChanged,
      use24h: use24h,
    ),
    TrackerType.duration => DurationInput(
      tracker: tracker,
      value: value,
      onChanged: onChanged,
    ),
    TrackerType.counter => CounterInput(
      tracker: tracker,
      value: value,
      onChanged: onChanged,
    ),
    TrackerType.number || TrackerType.decimal => NumberInput(
      tracker: tracker,
      value: value,
      onChanged: onChanged,
      lastValue: lastNumber,
    ),
    TrackerType.rating => RatingInput(
      tracker: tracker,
      value: value,
      onChanged: onChanged,
    ),
    TrackerType.text || TrackerType.longText => TextInput(
      tracker: tracker,
      value: value,
      onChanged: onChanged,
      suggestions: suggestions,
      previousText: previousText,
    ),
    TrackerType.image || TrackerType.file => AttachmentInput(
      tracker: tracker,
      value: value,
      onChanged: onChanged,
    ),
  };
}
