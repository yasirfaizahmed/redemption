import 'package:material_ui/material_ui.dart';

/// Helpers for times stored as "minutes since midnight" (0–1439).
abstract final class Clock {
  static const minutesPerDay = 24 * 60;

  static int normalize(int minutes) =>
      ((minutes % minutesPerDay) + minutesPerDay) % minutesPerDay;

  static int fromDateTime(DateTime dt) => dt.hour * 60 + dt.minute;

  static int fromTimeOfDay(TimeOfDay t) => t.hour * 60 + t.minute;

  static TimeOfDay toTimeOfDay(int minutes) {
    final m = normalize(minutes);
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  /// Minutes elapsed since the logical start of the day. Lets us compare
  /// 23:30 and 00:30 correctly when the day starts at e.g. 03:00.
  static int relativeToDayStart(int minutes, int dayStartMinutes) =>
      normalize(minutes - dayStartMinutes);

  static int fromRelative(int relative, int dayStartMinutes) =>
      normalize(relative + dayStartMinutes);

  /// `HH:mm` (24h) or `h:mm a` (12h).
  static String format(int minutes, {bool use24h = true}) {
    final m = normalize(minutes);
    final h = m ~/ 60;
    final min = (m % 60).toString().padLeft(2, '0');
    if (use24h) return '${h.toString().padLeft(2, '0')}:$min';
    final period = h < 12 ? 'AM' : 'PM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$min $period';
  }

  /// Human friendly duration, e.g. `1h 30m`, `45m`.
  static String formatDuration(int totalMinutes) {
    final neg = totalMinutes < 0;
    final m = totalMinutes.abs();
    final h = m ~/ 60;
    final rest = m % 60;
    final s = h == 0
        ? '${rest}m'
        : rest == 0
        ? '${h}h'
        : '${h}h ${rest}m';
    return neg ? '-$s' : s;
  }
}
