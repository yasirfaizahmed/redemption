import 'package:flutter_test/flutter_test.dart';
import 'package:redemption/core/time/day.dart';
import 'package:redemption/core/time/time_of_day_x.dart';

void main() {
  group('Day', () {
    test('parses and formats keys', () {
      final d = Day.parse('2026-03-09');
      expect(d, const Day(2026, 3, 9));
      expect(d.key, '2026-03-09');
    });

    test('adds days across month, year and DST boundaries', () {
      expect(const Day(2026, 1, 31).addDays(1), const Day(2026, 2, 1));
      expect(const Day(2026, 12, 31).addDays(1), const Day(2027, 1, 1));
      // European/US DST change weeks — no off-by-one.
      expect(const Day(2026, 3, 28).addDays(2), const Day(2026, 3, 30));
      expect(const Day(2026, 11, 1).addDays(1), const Day(2026, 11, 2));
      expect(const Day(2028, 2, 28).addDays(1), const Day(2028, 2, 29));
    });

    test('difference and weekday', () {
      expect(const Day(2026, 4, 10).difference(const Day(2026, 1, 1)), 99);
      expect(const Day(2026, 10, 12).weekday, DateTime.monday);
      expect(const Day(2026, 10, 18).weekday, DateTime.sunday);
    });

    test('range is inclusive', () {
      final days = Day.range(
        const Day(2026, 1, 30),
        const Day(2026, 2, 2),
      ).toList();
      expect(days.length, 4);
      expect(days.last, const Day(2026, 2, 2));
    });

    test('current day respects the configured day start', () {
      final lateNight = DateTime(2026, 10, 11, 0, 40);
      expect(
        Day.current(dayStartMinutes: 180, now: lateNight),
        const Day(2026, 10, 10),
        reason:
            '00:40 belongs to the previous day when the day starts at 03:00',
      );
      expect(
        Day.current(dayStartMinutes: 0, now: lateNight),
        const Day(2026, 10, 11),
      );
      expect(
        Day.current(dayStartMinutes: 180, now: DateTime(2026, 10, 11, 4, 30)),
        const Day(2026, 10, 11),
      );
    });
  });

  group('Clock', () {
    test('formats 24h and 12h', () {
      expect(Clock.format(4 * 60 + 5), '04:05');
      expect(Clock.format(13 * 60 + 30, use24h: false), '1:30 PM');
      expect(Clock.format(0, use24h: false), '12:00 AM');
    });

    test('relative to day start handles midnight wrap', () {
      // Day starts 03:00 → 23:30 is 1230 min in, 00:30 is 1290 min in.
      expect(Clock.relativeToDayStart(23 * 60 + 30, 180), 1230);
      expect(Clock.relativeToDayStart(30, 180), 1290);
      expect(Clock.fromRelative(1290, 180), 30);
    });

    test('formats durations', () {
      expect(Clock.formatDuration(45), '45m');
      expect(Clock.formatDuration(60), '1h');
      expect(Clock.formatDuration(95), '1h 35m');
    });
  });
}
