import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

final _log = Logger('AppLimits');

/// An app (with its variants) that can be given a daily limit.
@immutable
class LimitedApp {
  const LimitedApp(this.id, this.name, this.covers);

  final String id;
  final String name;

  /// What else shares this app's time.
  final String covers;

  /// Apps that play in the background (Spotify, YouTube Music, and YouTube
  /// with Vanced): their limit needs background listening counted.
  static const playsInBackground = {'youtube', 'ytmusic', 'spotify'};

  static const all = [
    LimitedApp('chrome', 'Chrome', 'Chrome, Beta, Dev and Canary'),
    LimitedApp('instagram', 'Instagram', 'Instagram and Instagram Lite'),
    LimitedApp('youtube', 'YouTube', 'YouTube, Vanced and ReVanced'),
    LimitedApp('ytmusic', 'YouTube Music', 'YT Music, Vanced and ReVanced'),
    LimitedApp('spotify', 'Spotify', 'Spotify and Spotify Lite'),
  ];

  /// The minutes a day one can choose (0: blocked all day).
  static const minuteChoices = [
    0, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, //
  ];
}

/// The limits as the phone keeps them, and today's use.
@immutable
class AppLimitsState {
  const AppLimitsState({
    this.quotas = const {},
    this.used = const {},
    this.guard = false,
    this.mediaAccess = false,
    this.autoTime,
  });

  /// Minutes a day, for apps with a (locked) limit.
  final Map<String, int> quotas;

  /// Time used today, per app id.
  final Map<String, Duration> used;

  /// The accessibility guard that counts and blocks is on.
  final bool guard;

  /// Background playback can be counted and paused.
  final bool mediaAccess;

  /// The phone sets its own date and time (null: unknown).
  final bool? autoTime;

  Duration usedOf(String id) => used[id] ?? Duration.zero;

  /// Time left today, or null when [id] has no limit.
  Duration? leftOf(String id) {
    final q = quotas[id];
    if (q == null) return null;
    final left = Duration(minutes: q) - usedOf(id);
    return left.isNegative ? Duration.zero : left;
  }
}

/// Daily app limits, kept by the phone so the app can never loosen them.
abstract class AppLimitsService {
  bool get isSupported;

  Future<AppLimitsState> load();

  /// Saves [quotas]; locked limits can only go down. Null when saved, else
  /// why not.
  Future<String?> lock(Map<String, int> quotas);

  Future<void> openSystemSetting(String which);
}

class ChannelAppLimitsService implements AppLimitsService {
  static const _channel = MethodChannel('redemption/alarm');

  @override
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  @override
  Future<AppLimitsState> load() async {
    if (!isSupported) return const AppLimitsState();
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('limits');
      if (m == null) return const AppLimitsState();
      final quotas = (m['quotas'] as Map?) ?? const {};
      final used = (m['used'] as Map?) ?? const {};
      return AppLimitsState(
        quotas: {
          for (final e in quotas.entries) '${e.key}': (e.value as num).toInt(),
        },
        used: {
          for (final e in used.entries)
            '${e.key}': Duration(milliseconds: (e.value as num).toInt()),
        },
        guard: m['guard'] == true,
        mediaAccess: m['mediaAccess'] == true,
        autoTime: m['autoTime'] as bool?,
      );
    } catch (e) {
      _log.warning('Could not read app limits: $e');
      return const AppLimitsState();
    }
  }

  @override
  Future<String?> lock(Map<String, int> quotas) async {
    if (!isSupported) return 'Only on Android';
    try {
      return await _channel.invokeMethod<String>('setLimits', {
        'quotas': quotas,
      });
    } catch (e) {
      _log.warning('Could not save app limits: $e');
      return 'Couldn’t save the limits.';
    }
  }

  @override
  Future<void> openSystemSetting(String which) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('openSetting', {'which': which});
    } catch (e) {
      _log.fine('openSetting $which: $e');
    }
  }
}
