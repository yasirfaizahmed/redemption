import 'package:flutter/foundation.dart';

/// A calendar date without a time-of-day or timezone (a "local date").
///
/// All day arithmetic is done on UTC midnights so daylight-saving transitions
/// can never produce off-by-one-day errors. Persisted as `YYYY-MM-DD`.
@immutable
class Day implements Comparable<Day> {
  const Day(this.year, this.month, this.day);

  factory Day.fromDateTime(DateTime dt) => Day(dt.year, dt.month, dt.day);

  /// Parses a `YYYY-MM-DD` key.
  factory Day.parse(String key) {
    final parts = key.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid day key', key);
    }
    return Day(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  /// The "logical" current day. A day is considered to start at
  /// [dayStartMinutes] past midnight, so logging sleep at 00:40 still belongs
  /// to the previous day when the day starts at 03:00.
  factory Day.current({required int dayStartMinutes, DateTime? now}) {
    final n = now ?? DateTime.now();
    final shifted = n.subtract(Duration(minutes: dayStartMinutes));
    return Day.fromDateTime(shifted);
  }

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// Local midnight of this day.
  DateTime toDateTime() => DateTime(year, month, day);

  Day addDays(int days) => Day.fromDateTime(_utc.add(Duration(days: days)));

  /// Whole days from [other] to this (positive when this is later).
  int difference(Day other) => _utc.difference(other._utc).inDays;

  /// ISO weekday: 1 = Monday … 7 = Sunday.
  int get weekday => _utc.weekday;

  bool isBefore(Day other) => compareTo(other) < 0;
  bool isAfter(Day other) => compareTo(other) > 0;
  bool isSameOrBefore(Day other) => compareTo(other) <= 0;
  bool isSameOrAfter(Day other) => compareTo(other) >= 0;

  String get key =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// Inclusive range of days from [start] to [end].
  static Iterable<Day> range(Day start, Day end) sync* {
    var d = start;
    while (d.isSameOrBefore(end)) {
      yield d;
      d = d.addDays(1);
    }
  }

  @override
  int compareTo(Day other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is Day &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => key;
}
