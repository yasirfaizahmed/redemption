import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show DateTimeComponents;
import 'package:flutter_test/flutter_test.dart';
import 'package:redemption/core/time/day.dart';
import 'package:redemption/domain/models.dart';
import 'package:redemption/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tzdata.initializeTimeZones();
  final kolkata = tz.getLocation('Asia/Kolkata');
  // Monday 12 October 2026, 10:00.
  final now = tz.TZDateTime(kolkata, 2026, 10, 12, 10);
  const monday = Day(2026, 10, 12);
  const leftOfficeAt = 16 * 60 + 30;

  List<ReminderSlot> slots({int weekdays = Weekdays.workweek, Day? skip}) =>
      NotificationService.slotsFor(
        trackerId: 7,
        weekdays: weekdays,
        minutes: leftOfficeAt,
        now: now,
        skipAt: skip == null
            ? null
            : NotificationService.occurrenceOn(
                skip,
                leftOfficeAt,
                dayStartMinutes: 180,
                location: kolkata,
              ),
      );

  test('a weekday reminder repeats weekly on each scheduled weekday', () {
    final s = slots();
    expect(s, hasLength(5));
    expect(
      s.every((r) => r.repeat == DateTimeComponents.dayOfWeekAndTime),
      isTrue,
    );
    expect(s.first.at, tz.TZDateTime(kolkata, 2026, 10, 12, 16, 30));
    expect({for (final r in s) r.id}, hasLength(5));
  });

  test('a tracker not needed today skips only today’s reminder', () {
    final s = slots(skip: monday);
    expect(s, hasLength(5));
    final mon = s.firstWhere((r) => r.at.weekday == DateTime.monday);
    expect(mon.repeat, isNull, reason: 'fires once, a week later');
    expect(mon.at, tz.TZDateTime(kolkata, 2026, 10, 19, 16, 30));
    expect(mon.id, slots().first.id, reason: 'same slot id as the repeat');
    for (final r in s.where((r) => r != mon)) {
      expect(r.repeat, DateTimeComponents.dayOfWeekAndTime);
    }
  });

  test('a daily reminder splits into weekdays to skip one day', () {
    expect(slots(weekdays: Weekdays.all), [
      (
        id: 1070,
        at: tz.TZDateTime(kolkata, 2026, 10, 12, 16, 30),
        repeat: DateTimeComponents.time,
      ),
    ]);
    final s = slots(weekdays: Weekdays.all, skip: monday);
    expect(s, hasLength(7));
    expect(s.where((r) => r.repeat == null).single.at.day, 19);
    expect(
      s.where((r) => r.repeat == DateTimeComponents.dayOfWeekAndTime),
      hasLength(6),
    );
  });

  test('nothing changes when today’s reminder has already fired', () {
    final evening = tz.TZDateTime(kolkata, 2026, 10, 12, 18);
    final s = NotificationService.slotsFor(
      trackerId: 7,
      weekdays: Weekdays.workweek,
      minutes: leftOfficeAt,
      now: evening,
      skipAt: NotificationService.occurrenceOn(
        monday,
        leftOfficeAt,
        dayStartMinutes: 180,
        location: kolkata,
      ),
    );
    expect(s.every((r) => r.repeat != null), isTrue);
    expect(s.firstWhere((r) => r.at.weekday == DateTime.monday).at.day, 19);
  });

  test('a reminder before the day starts belongs to the night before', () {
    expect(
      NotificationService.occurrenceOn(
        monday,
        60,
        dayStartMinutes: 180,
        location: kolkata,
      ),
      tz.TZDateTime(kolkata, 2026, 10, 13, 1),
    );
    expect(
      NotificationService.occurrenceOn(
        monday,
        leftOfficeAt,
        dayStartMinutes: 180,
        location: kolkata,
      ),
      tz.TZDateTime(kolkata, 2026, 10, 12, 16, 30),
    );
  });
}
