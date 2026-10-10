import '../core/time/time_of_day_x.dart';
import 'models.dart';
import 'tracker_config.dart';
import 'tracker_goal.dart';
import 'tracker_type.dart';
import 'tracker_value.dart';

/// Human-readable strings for values and goals.
abstract final class Fmt {
  static String number(double v, {int decimals = 0}) {
    if (decimals == 0 || v == v.roundToDouble()) {
      final rounded = v.round();
      return _groupThousands(rounded);
    }
    return v.toStringAsFixed(decimals);
  }

  static String _groupThousands(int v) {
    final s = v.abs().toString();
    final buf = StringBuffer(v < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String withUnit(double v, TrackerConfig c, {int decimals = 0}) {
    final n = number(v, decimals: decimals);
    return c.unit.isEmpty ? n : '$n ${c.unit}';
  }

  static String percent(double fraction) => '${(fraction * 100).round()}%';

  static String bytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  static int decimalsFor(Tracker t) =>
      t.type == TrackerType.decimal ? t.config.decimals : 0;

  /// Short summary of a logged value, e.g. "04:52", "6 / 8 glasses".
  static String value(Tracker t, TrackerValue v, {bool use24h = true}) {
    final c = t.config;
    return switch (v) {
      BoolValue(:final value) => value ? c.yesLabel : c.noLabel,
      TimeValue(:final minutes) => Clock.format(minutes, use24h: use24h),
      DurationValue(:final minutes) => Clock.formatDuration(minutes),
      NumberValue(:final value) => switch (t.type) {
        TrackerType.rating => '${number(value)} / ${c.ratingMax}',
        TrackerType.counter when t.goal is NumberGoal =>
          '${number(value)} / ${withUnit((t.goal as NumberGoal).value, c)}',
        _ => withUnit(value, c, decimals: decimalsFor(t)),
      },
      ChoiceValue(:final optionId) =>
        c.optionById(optionId)?.display ?? optionId,
      MultiChoiceValue(:final optionIds) =>
        optionIds.map((id) => c.optionById(id)?.label ?? id).join(', '),
      TextValue(:final text) => text.trim().replaceAll(
        RegExp(r'\s*\n\s*'),
        ' · ',
      ),
      AttachmentsValue(:final files) =>
        '${files.length} ${t.type == TrackerType.image ? 'photo' : 'file'}'
            '${files.length == 1 ? '' : 's'}',
    };
  }

  /// Describes a chart/aggregate number for a tracker (average, total…).
  static String aggregate(Tracker t, double v, {bool use24h = true}) =>
      switch (t.type) {
        TrackerType.time => Clock.format(v.round(), use24h: use24h),
        TrackerType.duration => Clock.formatDuration(v.round()),
        TrackerType.rating => '${v.toStringAsFixed(1)} / ${t.config.ratingMax}',
        TrackerType.decimal => withUnit(
          v,
          t.config,
          decimals: t.config.decimals,
        ),
        _ => withUnit(v, t.config, decimals: v == v.roundToDouble() ? 0 : 1),
      };

  static String goal(Tracker t, {bool use24h = true}) {
    final g = t.goal;
    final c = t.config;
    String n(double v) => switch (t.type) {
      TrackerType.duration => Clock.formatDuration(v.round()),
      TrackerType.multiChoice => '${number(v)} selected',
      TrackerType.image || TrackerType.file => '${number(v)} files',
      _ => withUnit(v, c, decimals: decimalsFor(t)),
    };
    return switch (g) {
      LoggedGoal() => 'Log it',
      BoolGoal(:final target) => target ? c.yesLabel : c.noLabel,
      ChoiceScoreGoal() =>
        c.options.where((o) => o.score >= 1).map((o) => o.label).join(' or '),
      NumberGoal(:final comparator, :final value, :final upper) =>
        switch (comparator) {
          NumberComparator.atLeast => 'At least ${n(value)}',
          NumberComparator.atMost => 'At most ${n(value)}',
          NumberComparator.between => '${n(value)} – ${n(upper ?? value)}',
        },
      TimeGoal(:final comparator, :final minutes, :final graceMinutes) =>
        '${comparator == TimeComparator.before ? 'Before' : 'After'} '
            '${Clock.format(minutes, use24h: use24h)}'
            '${graceMinutes > 0 ? ' · ${graceMinutes}m grace' : ''}',
    };
  }
}
