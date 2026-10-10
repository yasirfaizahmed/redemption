import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models.dart';
import '../../../domain/tracker_type.dart';
import '../../../domain/tracker_value.dart';

/// Free text with tap-to-add suggestion chips mined from history, plus a
/// "same as yesterday" shortcut — most days you barely need the keyboard.
class TextInput extends StatefulWidget {
  const TextInput({
    super.key,
    required this.tracker,
    required this.value,
    required this.onChanged,
    required this.suggestions,
    this.previousText,
  });

  final Tracker tracker;
  final TrackerValue? value;
  final ValueChanged<TrackerValue?> onChanged;
  final List<String> suggestions;

  /// Value logged on the previous day, if any.
  final String? previousText;

  @override
  State<TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<TextInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value is TextValue ? (widget.value! as TextValue).text : '',
  );

  bool get _multiline => widget.tracker.type == TrackerType.longText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _emit(text);
  }

  void _emit(String text) =>
      widget.onChanged(text.trim().isEmpty ? null : TextValue(text));

  void _append(String item) {
    HapticFeedback.selectionClick();
    final current = _controller.text.trimRight();
    if (!_multiline || current.isEmpty) {
      _setText(_multiline ? item : item);
      return;
    }
    final separator = current.endsWith(',') ? ' ' : ', ';
    _setText('$current$separator$item');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing = _controller.text.toLowerCase();
    final chips = [
      for (final s in widget.suggestions)
        if (!existing.contains(s.toLowerCase())) s,
    ];
    final placeholder = widget.tracker.config.placeholder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          minLines: _multiline ? 3 : 1,
          maxLines: _multiline ? 8 : 1,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: _multiline
              ? TextInputAction.newline
              : TextInputAction.done,
          decoration: InputDecoration(
            hintText: placeholder.isEmpty
                ? 'Type, or tap suggestions below'
                : placeholder,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _setText('')),
                  ),
          ),
          onChanged: (t) => setState(() => _emit(t)),
        ),
        if (widget.previousText != null &&
            widget.previousText!.trim().isNotEmpty &&
            _controller.text.trim() != widget.previousText!.trim()) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Same as yesterday'),
              onPressed: () => setState(() => _setText(widget.previousText!)),
            ),
          ),
        ],
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Tap to add',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in chips)
                ActionChip(
                  label: Text(s),
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  onPressed: () => setState(() => _append(s)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
