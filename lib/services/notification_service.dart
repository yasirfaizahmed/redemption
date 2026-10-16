import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Day;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:logging/logging.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/time/day.dart';
import '../domain/app_settings.dart';
import '../domain/formatting.dart';
import '../domain/models.dart';

final _log = Logger('Notifications');

/// One scheduled reminder: repeating daily or weekly, or once ([repeat] null).
typedef ReminderSlot = ({int id, tz.TZDateTime at, DateTimeComponents? repeat});

/// Local reminders. Everything is scheduled on-device; nothing needs a server.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  bool _ready = false;

  static const checkInId = 1;
  static const _trackerBase = 1000;

  /// Notification payloads tapped while the app is running.
  Stream<String> get taps => _taps.stream;

  /// Payload of the notification that launched the app, if any.
  String? launchPayload;

  bool get isReady => _ready;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<void> init() async {
    if (!_supported) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (e) {
        _log.warning('Could not resolve local timezone, using UTC', e);
      }
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_redemption'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (r) {
          if (r.payload != null) _taps.add(r.payload!);
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        launchPayload = launch!.notificationResponse?.payload;
      }
      _ready = true;
      _log.info('Initialised (tz: ${tz.local.name})');
    } catch (e, s) {
      _log.severe('Initialisation failed', e, s);
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } catch (e, s) {
      _log.warning('Permission request failed', e, s);
      return false;
    }
  }

  Future<bool?> areEnabled() async {
    if (!_ready || !Platform.isAndroid) return null;
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.areNotificationsEnabled();
  }

  /// Opens the system screen that grants exact alarms (Android 12+).
  Future<void> requestExactAlarms() async {
    if (!_ready || !Platform.isAndroid) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
  }

  Future<int> pendingCount() async {
    if (!_ready) return 0;
    return (await _plugin.pendingNotificationRequests()).length;
  }

  /// Re-creates every scheduled reminder from the current trackers/settings.
  ///
  /// [skippedToday] holds trackers a skip rule switched off on [today]
  /// (e.g. "Left office" on a work-from-home day): today's reminder is left
  /// out and that slot fires again a week later.
  Future<void> sync({
    required List<Tracker> trackers,
    required AppSettings settings,
    Day? today,
    Set<int> skippedToday = const {},
  }) async {
    if (!_ready) return;
    try {
      // Only scheduled reminders: an "update ready" notice on screen stays.
      await _plugin.cancelAllPendingNotifications();
      final mode = await _scheduleMode();
      final now = tz.TZDateTime.now(tz.local);
      var count = 0;
      for (final t in trackers) {
        final at = t.reminderMinutes ?? t.anchorMinutes;
        if (!t.reminderEnabled || at == null || t.isArchived) continue;
        final body = t.description.isNotEmpty
            ? t.description
            : 'Goal: ${Fmt.goal(t, use24h: settings.use24h)}. Every rep rewires.';
        final skipAt = today != null && skippedToday.contains(t.id)
            ? occurrenceOn(
                today,
                at,
                dayStartMinutes: settings.dayStartMinutes,
                location: tz.local,
              )
            : null;
        final slots = slotsFor(
          trackerId: t.id,
          weekdays: t.weekdays,
          minutes: at,
          now: now,
          skipAt: skipAt,
        );
        for (final slot in slots) {
          await _schedule(
            slot,
            title: t.name,
            body: body,
            payload: 'tracker:${t.id}',
            mode: mode,
            channel: _reminderChannel,
          );
          count++;
        }
        if (slots.any((s) => s.repeat == null)) {
          _log.info('Today’s reminder for tracker ${t.id} skipped');
        }
      }
      if (settings.checkInEnabled) {
        await _schedule(
          (
            id: checkInId,
            at: nextInstance(settings.checkInMinutes, now: now),
            repeat: DateTimeComponents.time,
          ),
          title: 'Evening check-in',
          body: 'Log what’s left for today. Never miss twice.',
          payload: 'today',
          mode: mode,
          channel: _checkInChannel,
        );
        count++;
      }
      _log.info('Scheduled $count reminders (${mode.name})');
    } catch (e, s) {
      _log.severe('Failed to sync reminders', e, s);
    }
  }

  Future<void> showTest() async {
    if (!_ready) return;
    await _plugin.show(
      id: 2,
      title: 'Redemption',
      body: 'Notifications are working. Bismillah — let’s go.',
      notificationDetails: _details(_reminderChannel),
    );
  }

  static const updateId = 3;

  /// "A new version is ready" — tapping it opens the update sheet.
  Future<void> showUpdate({
    required String version,
    required bool ready,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      id: updateId,
      title: ready
          ? 'Redemption $version is ready to install'
          : 'Redemption $version is available',
      body: ready
          ? 'Tap to install the update.'
          : 'Tap to see what’s new and update.',
      notificationDetails: _details(_updateChannel),
      payload: 'update',
    );
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;
    final canExact =
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        false;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static const _reminderChannel = (
    id: 'tracker_reminders',
    name: 'Tracker reminders',
    description: 'Reminders you set on individual trackers',
  );
  static const _updateChannel = (
    id: 'app_updates',
    name: 'App updates',
    description: 'When a new version of Redemption is available',
  );
  static const _checkInChannel = (
    id: 'daily_check_in',
    name: 'Daily check-in',
    description: 'One evening nudge to complete the day',
  );

  NotificationDetails _details(
    ({String id, String name, String description}) channel,
  ) => NotificationDetails(
    android: AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  Future<void> _schedule(
    ReminderSlot slot, {
    required String title,
    required String body,
    required String payload,
    required AndroidScheduleMode mode,
    required ({String id, String name, String description}) channel,
  }) => _plugin.zonedSchedule(
    id: slot.id,
    title: title,
    body: body,
    scheduledDate: slot.at,
    notificationDetails: _details(channel),
    androidScheduleMode: mode,
    payload: payload,
    matchDateTimeComponents: slot.repeat,
  );

  /// The reminders of one tracker at [minutes] on its [weekdays]: one daily
  /// repeat, or a weekly repeat per weekday.
  ///
  /// When [skipAt] is the next time a slot would fire (the tracker isn't
  /// needed today), that slot fires once, a week later, instead — the next
  /// sync (any app start or change) makes it repeat again.
  static List<ReminderSlot> slotsFor({
    required int trackerId,
    required int weekdays,
    required int minutes,
    required tz.TZDateTime now,
    tz.TZDateTime? skipAt,
  }) {
    final base = _trackerBase + trackerId * 10;
    bool skips(tz.TZDateTime at) =>
        skipAt != null && at.isAtSameMomentAs(skipAt);
    if (weekdays == Weekdays.all) {
      final next = nextInstance(minutes, now: now);
      if (!skips(next)) {
        return [(id: base, at: next, repeat: DateTimeComponents.time)];
      }
    }
    return [
      for (var wd = 1; wd <= 7; wd++)
        if (Weekdays.has(weekdays, wd))
          switch (nextInstance(minutes, weekday: wd, now: now)) {
            final next when skips(next) => (
              id: base + wd,
              at: tz.TZDateTime(
                next.location,
                next.year,
                next.month,
                next.day + 7,
                next.hour,
                next.minute,
              ),
              repeat: null,
            ),
            final next => (
              id: base + wd,
              at: next,
              repeat: DateTimeComponents.dayOfWeekAndTime,
            ),
          },
    ];
  }

  /// When a reminder at [minutes] fires for the logical [day]: on its date,
  /// or on the next one for a time before the day starts (01:00 belongs to
  /// the night before when days start at 04:00).
  static tz.TZDateTime occurrenceOn(
    Day day,
    int minutes, {
    required int dayStartMinutes,
    required tz.Location location,
  }) => tz.TZDateTime(
    location,
    day.year,
    day.month,
    day.day + (minutes < dayStartMinutes ? 1 : 0),
    minutes ~/ 60,
    minutes % 60,
  );

  /// Next occurrence of [minutes] past midnight (optionally on an ISO
  /// [weekday]) in the local timezone, built per-date so DST is respected.
  static tz.TZDateTime nextInstance(
    int minutes, {
    int? weekday,
    tz.TZDateTime? now,
  }) {
    final n = now ?? tz.TZDateTime.now(tz.local);
    for (var offset = 0; offset <= 8; offset++) {
      final candidate = tz.TZDateTime(
        n.location,
        n.year,
        n.month,
        n.day + offset,
        minutes ~/ 60,
        minutes % 60,
      );
      if (!candidate.isAfter(n)) continue;
      if (weekday != null && candidate.weekday != weekday) continue;
      return candidate;
    }
    throw StateError('unreachable');
  }
}
