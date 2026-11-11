import 'dart:async';
import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger('WakeAlarm');

/// A wake-up alarm that rings inside Redemption until its sums are solved.
@immutable
class WakeAlarm {
  const WakeAlarm({required this.id, required this.at, this.label = ''});

  final int id;
  final DateTime at;

  /// What it is for, e.g. "5 sleep cycles".
  final String label;

  /// One alarm per minute: setting the same minute again replaces it.
  static int idFor(DateTime at) => at.millisecondsSinceEpoch ~/ 60000;

  @override
  bool operator ==(Object other) =>
      other is WakeAlarm && other.id == id && other.at == at;

  @override
  int get hashCode => Object.hash(id, at);

  @override
  String toString() => 'WakeAlarm($id at $at)';
}

/// What the phone allows the alarm to do. Null: can't tell (not Android).
@immutable
class AlarmChecks {
  const AlarmChecks({
    this.notifications,
    this.fullScreen,
    this.guard,
    this.batteryUnrestricted,
  });

  /// Notifications are allowed (the ringing alarm is one).
  final bool? notifications;

  /// The alarm may open over the lock screen.
  final bool? fullScreen;

  /// The "Alarm guard" accessibility service is on: while an alarm rings it
  /// closes the power menu, the uninstall dialog and Settings.
  final bool? guard;

  /// Android won't put the app to sleep to save battery.
  final bool? batteryUnrestricted;
}

/// Wake-up alarms that ring in the app. Android only.
abstract class WakeAlarmService {
  /// Whether alarms can ring inside the app on this device.
  bool get isSupported;

  /// Alarms ringing right now (the current value first, then changes).
  Stream<List<WakeAlarm>> get ringing;

  /// Alarms set and not yet ringing (the current value first, then changes).
  Stream<List<WakeAlarm>> get scheduled;

  /// Sets an alarm for [at]. False when the phone refused it.
  Future<bool> schedule(DateTime at, {String label = ''});

  /// Removes an alarm that hasn't rung yet (one already due can't be
  /// cancelled — only solved).
  Future<void> cancel(int id);

  /// Silences a ringing alarm — only called once its sums are solved.
  Future<bool> stop(int id);

  Future<AlarmChecks> checks();

  /// Opens a system screen: 'accessibility', 'appInfo', 'fullScreen',
  /// 'notifications' or 'battery'.
  Future<void> openSystemSetting(String which);

  /// The sums are on screen: only now may the alarm guard hold the phone.
  Future<void> sumsShown();

  /// No alarm rings any more: the app stops showing over the lock screen.
  Future<void> ringingEnded();
}

/// [WakeAlarmService] on the `alarm` plugin: a foreground service that keeps
/// ringing at full, locked volume when the app is closed, and again after a
/// restart.
class PluginWakeAlarmService implements WakeAlarmService {
  static const sound = 'assets/audio/alarm.wav';
  static const _channel = MethodChannel('redemption/alarm');

  /// Alarms set and not yet solved: "id|epochMs|label".
  static const _owedKey = 'redemption.wakeAlarms.owed';

  /// An unsolved alarm older than this isn't brought back.
  static const _owedFor = Duration(hours: 12);

  bool _ready = false;

  @override
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Connects to alarms set earlier (one may be ringing right now).
  Future<void> init() async {
    if (!isSupported) return;
    try {
      await Alarm.init();
      _ready = true;
      await _ringOwed();
      _log.info(
        'Ready: ${Alarm.scheduled.value.alarms.length} set, '
        '${Alarm.ringing.value.alarms.length} ringing',
      );
    } catch (e, s) {
      _log.severe('Alarm init failed', e, s);
    }
  }

  Future<List<WakeAlarm>> _readOwed() async {
    final prefs = await SharedPreferences.getInstance();
    return [
      for (final line in prefs.getStringList(_owedKey) ?? const <String>[])
        if (line.split('|') case [final id, final ms, ...final label])
          if ((int.tryParse(id), int.tryParse(ms)) case (final i?, final m?))
            WakeAlarm(
              id: i,
              at: DateTime.fromMillisecondsSinceEpoch(m),
              label: label.join('|'),
            ),
    ];
  }

  Future<void> _writeOwed(List<WakeAlarm> owed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_owedKey, [
      for (final a in owed) '${a.id}|${a.at.millisecondsSinceEpoch}|${a.label}',
    ]);
  }

  /// An alarm that came due and wasn't solved — the phone killed it
  /// mid-ring, or it was dropped — rings again now. The plugin itself
  /// forgets an overdue alarm it doesn't see ringing.
  Future<void> _ringOwed() async {
    final now = DateTime.now();
    final owed = await _readOwed();
    final ringing = {for (final a in Alarm.ringing.value.alarms) a.id};
    final scheduled = {for (final a in Alarm.scheduled.value.alarms) a.id};
    final keep = <WakeAlarm>[];
    final due = <WakeAlarm>[];
    for (final a in owed) {
      if (a.at.isAfter(now)) {
        keep.add(a);
        // Set, but lost by the plugin: set it again.
        if (!scheduled.contains(a.id)) await _arm(a.id, a.at, a.label);
      } else if (now.difference(a.at) > _owedFor) {
        _log.info('Dropping alarm ${a.id} from ${a.at}: too old to ring');
      } else {
        keep.add(a);
        due.add(a);
      }
    }
    await _writeOwed(keep);
    // Several overdue alarms ring as one (solving it settles them all):
    // only the latest is re-armed, so none can come back on its own later.
    if (due.isNotEmpty && !due.any((a) => ringing.contains(a.id))) {
      final last = due.reduce((a, b) => a.at.isAfter(b.at) ? a : b);
      _log.warning('Alarm ${last.id} due ${last.at} was never solved: ringing');
      await _arm(last.id, now.add(const Duration(seconds: 6)), last.label);
    }
  }

  static List<WakeAlarm> _list(AlarmSet set) => [
    for (final a in set.alarms)
      WakeAlarm(id: a.id, at: a.dateTime, label: a.payload ?? ''),
  ]..sort((a, b) => a.at.compareTo(b.at));

  @override
  Stream<List<WakeAlarm>> get ringing =>
      _ready ? Alarm.ringing.map(_list) : Stream.value(const []);

  @override
  Stream<List<WakeAlarm>> get scheduled =>
      _ready ? Alarm.scheduled.map(_list) : Stream.value(const []);

  @override
  Future<bool> schedule(DateTime at, {String label = ''}) async {
    if (!_ready) return false;
    final id = WakeAlarm.idFor(at);
    final ok = await _arm(id, at, label);
    if (ok) {
      await _writeOwed([
        for (final a in await _readOwed())
          if (a.id != id) a,
        WakeAlarm(id: id, at: at, label: label),
      ]);
    }
    return ok;
  }

  Future<void> _forget(int id) async => _writeOwed([
    for (final a in await _readOwed())
      if (a.id != id) a,
  ]);

  Future<bool> _arm(int id, DateTime at, String label) async {
    try {
      final ok = await Alarm.set(
        alarmSettings: AlarmSettings(
          id: id,
          dateTime: at,
          assetAudioPath: sound,
          // Rings, at full volume the buttons can't lower, until stopped.
          volumeSettings: const VolumeSettings.fixed(
            volume: 1,
            volumeEnforced: true,
            showSystemUI: false,
          ),
          // Closing the app or swiping the notification doesn't stop it,
          // and a phone that was off rings it when it comes back on.
          warningNotificationOnKill: false,
          androidStopAlarmOnTermination: false,
          androidStaleAfter: null,
          payload: label,
          notificationSettings: NotificationSettings(
            title: 'Wake up — solve the sums to stop',
            body: label.isEmpty ? 'Tap to open Redemption' : label,
            icon: 'ic_stat_redemption',
            androidStopAlarmOnDismiss: false,
          ),
        ),
      );
      _log.info('Alarm $id for $at set: $ok');
      return ok;
    } catch (e, s) {
      _log.severe('Setting alarm $id failed', e, s);
      return false;
    }
  }

  @override
  Future<void> cancel(int id) async {
    if (!_ready) return;
    final owed = await _readOwed();
    final due = owed.any((a) => a.id == id && !a.at.isAfter(DateTime.now()));
    if (due) {
      _log.warning('Alarm $id is due: it can only be solved, not cancelled');
      return;
    }
    try {
      await _forget(id);
      await Alarm.stop(id);
      _log.info('Alarm $id cancelled');
    } catch (e, s) {
      _log.warning('Cancelling alarm $id failed', e, s);
    }
  }

  @override
  Future<bool> stop(int id) async {
    if (!_ready) return false;
    try {
      final ok = await Alarm.stop(id);
      // Solving settles every alarm already due, so none rings again later.
      if (ok) {
        final now = DateTime.now();
        await _writeOwed([
          for (final a in await _readOwed())
            if (a.id != id && a.at.isAfter(now)) a,
        ]);
      }
      _log.info('Alarm $id stopped: $ok');
      return ok;
    } catch (e, s) {
      _log.severe('Stopping alarm $id failed', e, s);
      return false;
    }
  }

  @override
  Future<AlarmChecks> checks() async {
    if (!isSupported) return const AlarmChecks();
    try {
      final m = await _channel.invokeMapMethod<String, bool?>('checks') ?? {};
      return AlarmChecks(
        notifications: m['notifications'],
        fullScreen: m['fullScreen'],
        guard: m['guard'],
        batteryUnrestricted: m['battery'],
      );
    } catch (e, s) {
      _log.warning('Alarm checks failed', e, s);
      return const AlarmChecks();
    }
  }

  @override
  Future<void> sumsShown() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('sumsShown');
    } catch (e) {
      _log.fine('sumsShown: $e');
    }
  }

  @override
  Future<void> ringingEnded() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('ringingEnded');
    } catch (e) {
      _log.fine('ringingEnded: $e');
    }
  }

  @override
  Future<void> openSystemSetting(String which) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('openSetting', {'which': which});
    } catch (e, s) {
      _log.warning('Opening $which settings failed', e, s);
    }
  }
}
