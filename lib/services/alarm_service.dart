import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

final _log = Logger('Alarm');

/// Sets alarms in the phone's Clock app (Android `ACTION_SET_ALARM`).
class AlarmService {
  const AlarmService();

  static const _channel = MethodChannel('redemption/alarm');

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Asks the Clock app to ring at [hour]:[minute] next, labelled
  /// [message]. Returns false when no Clock app takes the request.
  Future<bool> setAlarm({
    required int hour,
    required int minute,
    required String message,
  }) async {
    if (!isSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('setAlarm', {
        'hour': hour,
        'minute': minute,
        'message': message,
      });
      _log.info('Alarm $hour:$minute requested: $ok');
      return ok ?? false;
    } on PlatformException catch (e, s) {
      _log.warning('Setting an alarm failed', e, s);
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
