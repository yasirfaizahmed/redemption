import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/palette.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../domain/formatting.dart';
import '../../../domain/models.dart';
import '../../../domain/tracker_config.dart';
import '../../../domain/tracker_goal.dart';
import '../../../domain/tracker_type.dart';
import '../../../domain/tracker_value.dart';

double? _numberOf(TrackerValue? v) => v is NumberValue ? v.value : null;

double _round(double v, int decimals) {
  final f = math.pow(10, decimals).toDouble();
  return (v * f).roundToDouble() / f;
}

/// Opens a numeric keyboard dialog. Fallback for exact values.
Future<double?> promptNumber(
  BuildContext context, {
  required String title,
  double? initial,
  bool decimal = false,
  String unit = '',
}) async {
  final controller = TextEditingController(
    text: initial == null
        ? ''
        : Fmt.number(initial, decimals: decimal ? 2 : 0).replaceAll(',', ''),
  );
  final result = await showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
          ),
        ],
        decoration: InputDecoration(suffixText: unit.isEmpty ? null : unit),
        onSubmitted: (v) =>
            Navigator.pop(context, double.tryParse(v.replaceAll(',', '.'))),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            double.tryParse(controller.text.replaceAll(',', '.')),
          ),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// Round button that repeats (and accelerates) while held.
class RepeatButton extends StatefulWidget {
  const RepeatButton({
    super.key,
    required this.icon,
    required this.onStep,
    required this.semanticLabel,
    this.size = 64,
  });

  final IconData icon;
  final VoidCallback onStep;
  final String semanticLabel;
  final double size;

  @override
  State<RepeatButton> createState() => _RepeatButtonState();
}

class _RepeatButtonState extends State<RepeatButton> {
  Timer? _timer;
  int _ticks = 0;

  void _start() {
    widget.onStep();
    HapticFeedback.selectionClick();
    _ticks = 0;
    _timer = Timer(const Duration(milliseconds: 400), _repeat);
  }

  void _repeat() {
    _ticks++;
    widget.onStep();
    if (_ticks % 5 == 0) HapticFeedback.selectionClick();
    final interval = math.max(30, 120 - _ticks * 6);
    _timer = Timer(Duration(milliseconds: interval), _repeat);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      onTap: widget.onStep,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _start(),
        onTapUp: (_) => _stop(),
        onTapCancel: _stop,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.icon,
            size: widget.size * 0.45,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Stepper (hold to accelerate), optional slider and preset chips.
class NumberInput extends StatelessWidget {
  const NumberInput({
    super.key,
    required this.tracker,
    required this.value,
    required this.onChanged,
    this.lastValue,
  });

  final Tracker tracker;
  final TrackerValue? value;
  final ValueChanged<TrackerValue?> onChanged;

  /// Most recent logged value on another day ("same as last time").
  final double? lastValue;

  TrackerConfig get _c => tracker.config;
  bool get _isDecimal => tracker.type == TrackerType.decimal;
  int get _decimals => _isDecimal ? math.max(_c.decimals, _stepDecimals) : 0;
  int get _stepDecimals {
    final s = _c.step.toString();
    final dot = s.indexOf('.');
    return dot < 0 || s.endsWith('.0') ? 0 : s.length - dot - 1;
  }

  double _clamp(double v) {
    var r = v;
    if (_c.min != null) r = math.max(_c.min!, r);
    if (_c.max != null) r = math.min(_c.max!, r);
    return _round(r, _decimals);
  }

  void _set(double v) => onChanged(NumberValue(_clamp(v)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _numberOf(value);
    final base = current ?? lastValue ?? _c.min ?? 0;
    final showSlider =
        _c.inputStyle == NumberInputStyle.slider &&
        _c.min != null &&
        _c.max != null;
    final presets = [
      ..._c.presets,
      if (lastValue != null && !_c.presets.contains(lastValue)) lastValue!,
    ];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RepeatButton(
              icon: Icons.remove_rounded,
              semanticLabel:
                  'Decrease by ${Fmt.number(_c.step, decimals: _decimals)}',
              onStep: () => _set((_numberOf(value) ?? base) - _c.step),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final v = await promptNumber(
                    context,
                    title: tracker.name,
                    initial: current,
                    decimal: _isDecimal,
                    unit: _c.unit,
                  );
                  if (v != null) _set(v);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            current == null
                                ? '—'
                                : Fmt.number(current, decimals: _decimals),
                            style: theme.textTheme.displayMedium,
                          ),
                        ),
                      ),
                      Text(
                        _c.unit.isEmpty
                            ? 'tap to type'
                            : '${_c.unit} · tap to type',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            RepeatButton(
              icon: Icons.add_rounded,
              semanticLabel:
                  'Increase by ${Fmt.number(_c.step, decimals: _decimals)}',
              onStep: () => _set(
                _numberOf(value) == null ? base : _numberOf(value)! + _c.step,
              ),
            ),
          ],
        ),
        if (showSlider) ...[
          const SizedBox(height: 12),
          Slider(
            value: (current ?? _c.min!).clamp(_c.min!, _c.max!),
            min: _c.min!,
            max: _c.max!,
            divisions: ((_c.max! - _c.min!) / _c.step).round().clamp(1, 1000),
            label: current == null
                ? null
                : Fmt.number(current, decimals: _decimals),
            onChanged: _set,
          ),
        ],
        if (presets.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in presets)
                ChoiceChip(
                  avatar: p == lastValue
                      ? const Icon(Icons.history_rounded, size: 16)
                      : null,
                  label: Text(Fmt.withUnit(p, _c, decimals: _decimals)),
                  selected: current == p,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    _set(p);
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A giant tap target that counts up towards the daily target.
class CounterInput extends StatelessWidget {
  const CounterInput({
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
    final theme = Theme.of(context);
    final c = tracker.config;
    final count = _numberOf(value) ?? 0;
    final goal = tracker.goal;
    final target =
        goal is NumberGoal && goal.comparator == NumberComparator.atLeast
        ? goal.value
        : null;
    final color = Color(tracker.color);
    final step = c.step <= 0 ? 1.0 : c.step;
    return Column(
      children: [
        Semantics(
          button: true,
          label:
              '${tracker.name}: ${Fmt.number(count)}${target != null ? ' of ${Fmt.number(target)}' : ''}. Tap to add ${Fmt.number(step)}',
          excludeSemantics: true,
          onTap: () => onChanged(NumberValue(count + step)),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              onChanged(NumberValue(count + step));
            },
            child: ProgressRing(
              size: 210,
              strokeWidth: 16,
              progress: target == null ? (count > 0 ? 1 : 0) : count / target,
              color: color,
              secondaryColor: count >= (target ?? double.infinity)
                  ? Palette.success
                  : color,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    child: Text(
                      Fmt.number(count),
                      style: theme.textTheme.displayLarge?.copyWith(height: 1),
                    ),
                  ),
                  Text(
                    target == null
                        ? (c.unit.isEmpty ? 'tap +${Fmt.number(step)}' : c.unit)
                        : 'of ${Fmt.withUnit(target, c)}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: count <= 0
                  ? null
                  : () => onChanged(
                      count - step <= 0 ? null : NumberValue(count - step),
                    ),
              icon: const Icon(Icons.remove_rounded),
              label: Text(Fmt.number(step)),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: () => onChanged(NumberValue(count + step)),
              icon: const Icon(Icons.add_rounded),
              label: Text(Fmt.number(step)),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Set exact value',
              onPressed: () async {
                final v = await promptNumber(
                  context,
                  title: tracker.name,
                  initial: count,
                  unit: c.unit,
                );
                if (v != null) onChanged(v <= 0 ? null : NumberValue(v));
              },
              icon: const Icon(Icons.edit_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

/// Stars, emoji faces or a numbered scale.
class RatingInput extends StatelessWidget {
  const RatingInput({
    super.key,
    required this.tracker,
    required this.value,
    required this.onChanged,
  });

  final Tracker tracker;
  final TrackerValue? value;
  final ValueChanged<TrackerValue?> onChanged;

  static const faces = ['😫', '🙁', '😐', '🙂', '😄'];
  static const faceLabels = ['Awful', 'Low', 'Okay', 'Good', 'Great'];

  void _pick(int v) {
    HapticFeedback.selectionClick();
    onChanged(NumberValue(v.toDouble()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _numberOf(value)?.round() ?? 0;
    final c = tracker.config;
    switch (c.ratingStyle) {
      case RatingStyle.stars:
        return Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (var i = 1; i <= c.ratingMax; i++)
              IconButton(
                iconSize: c.ratingMax > 7 ? 30 : 44,
                tooltip: '$i of ${c.ratingMax}',
                onPressed: () => _pick(i),
                icon: Icon(
                  i <= current
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: i <= current
                      ? Palette.gold
                      : theme.colorScheme.outline,
                ),
              ),
          ],
        );
      case RatingStyle.emoji:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 1; i <= 5; i++)
              Semantics(
                button: true,
                selected: current == i,
                label: faceLabels[i - 1],
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => _pick(i),
                  child: AnimatedScale(
                    scale: current == i ? 1.25 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: current == i
                            ? theme.colorScheme.primaryContainer
                            : Colors.transparent,
                      ),
                      child: Text(
                        faces[i - 1],
                        style: TextStyle(
                          fontSize: 34,
                          color: current == 0 || current == i
                              ? null
                              : Colors.black.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      case RatingStyle.scale:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 1; i <= c.ratingMax; i++)
              () {
                final t = c.ratingMax == 1 ? 1.0 : (i - 1) / (c.ratingMax - 1);
                final color = Color.lerp(Palette.failure, Palette.success, t)!;
                final selected = current == i;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: '$i of ${c.ratingMax}',
                  excludeSemantics: true,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _pick(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? color : color.withValues(alpha: 0.14),
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Text(
                        '$i',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: selected ? Colors.white : color,
                        ),
                      ),
                    ),
                  ),
                );
              }(),
          ],
        );
    }
  }
}
