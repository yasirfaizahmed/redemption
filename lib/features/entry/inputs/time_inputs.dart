import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/time/time_of_day_x.dart';
import '../../../domain/models.dart';
import '../../../domain/tracker_value.dart';

CupertinoThemeData _wheelTheme(BuildContext context) {
  final theme = Theme.of(context);
  return CupertinoThemeData(
    brightness: theme.brightness,
    primaryColor: theme.colorScheme.primary,
    textTheme: CupertinoTextThemeData(
      dateTimePickerTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
      ),
    ),
  );
}

/// One-tap "Now", fine adjust chips and a scroll wheel.
class TimeInput extends StatefulWidget {
  const TimeInput({
    super.key,
    required this.tracker,
    required this.value,
    required this.onChanged,
    required this.use24h,
  });

  final Tracker tracker;
  final TrackerValue? value;
  final ValueChanged<TrackerValue?> onChanged;
  final bool use24h;

  @override
  State<TimeInput> createState() => _TimeInputState();
}

class _TimeInputState extends State<TimeInput> {
  /// Bumped only on external changes so the wheel is not rebuilt mid-scroll.
  int _wheelRevision = 0;

  int get _minutes => widget.value is TimeValue
      ? (widget.value! as TimeValue).minutes
      : Clock.fromDateTime(DateTime.now());

  void _set(int minutes) {
    HapticFeedback.selectionClick();
    setState(() => _wheelRevision++);
    widget.onChanged(TimeValue(Clock.normalize(minutes)));
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _minutes;
    final now = DateTime.now();
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => _set(Clock.fromDateTime(DateTime.now())),
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('Log the current time'),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (i, delta) in const [-15, -5, 5, 15].indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => _set(minutes + delta),
                  child: Text(delta > 0 ? '+${delta}m' : '${delta}m'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: CupertinoTheme(
            data: _wheelTheme(context),
            child: CupertinoDatePicker(
              key: ValueKey(_wheelRevision),
              mode: CupertinoDatePickerMode.time,
              use24hFormat: widget.use24h,
              initialDateTime: DateTime(
                now.year,
                now.month,
                now.day,
                minutes ~/ 60,
                minutes % 60,
              ),
              onDateTimeChanged: (dt) =>
                  widget.onChanged(TimeValue(Clock.fromDateTime(dt))),
            ),
          ),
        ),
      ],
    );
  }
}

/// Presets for common lengths plus an hour/minute wheel.
class DurationInput extends StatefulWidget {
  const DurationInput({
    super.key,
    required this.tracker,
    required this.value,
    required this.onChanged,
  });

  final Tracker tracker;
  final TrackerValue? value;
  final ValueChanged<TrackerValue?> onChanged;

  static const _defaultPresets = [15.0, 30.0, 45.0, 60.0, 90.0, 120.0];

  @override
  State<DurationInput> createState() => _DurationInputState();
}

class _DurationInputState extends State<DurationInput> {
  int _wheelRevision = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = widget.value;
    final minutes = value is DurationValue ? value.minutes : 0;
    final presets = widget.tracker.config.presets.isEmpty
        ? DurationInput._defaultPresets
        : widget.tracker.config.presets;
    return Column(
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            minutes == 0 ? '0m' : Clock.formatDuration(minutes),
            style: theme.textTheme.displayMedium,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in presets)
              ChoiceChip(
                label: Text(Clock.formatDuration(p.round())),
                selected: minutes == p.round(),
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _wheelRevision++);
                  widget.onChanged(DurationValue(p.round()));
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: CupertinoTheme(
            data: _wheelTheme(context),
            child: CupertinoTimerPicker(
              key: ValueKey(_wheelRevision),
              mode: CupertinoTimerPickerMode.hm,
              initialTimerDuration: Duration(minutes: minutes),
              onTimerDurationChanged: (d) => widget.onChanged(
                d.inMinutes == 0 ? null : DurationValue(d.inMinutes),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
