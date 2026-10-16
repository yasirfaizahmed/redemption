import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/app_settings.dart';
import '../domain/models.dart';
import '../features/settings/app_update_ui.dart';
import '../state/app_update.dart';
import '../state/drive_sync.dart';
import '../state/providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

final _log = Logger('App');

class RedemptionApp extends ConsumerStatefulWidget {
  const RedemptionApp({super.key});

  @override
  ConsumerState<RedemptionApp> createState() => _RedemptionAppState();
}

class _RedemptionAppState extends ConsumerState<RedemptionApp> {
  late final AppLifecycleListener _lifecycle;
  late final DriveAutoBackup _autoBackup;
  late final AutoUpdateChecker _updates;
  StreamSubscription<String>? _taps;
  Timer? _syncDebounce;

  @override
  void initState() {
    super.initState();
    _autoBackup = DriveAutoBackup(ref)..start();
    _updates = AutoUpdateChecker(ref)..start();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(clockProvider.notifier).refresh();
        _updates.onResume();
      },
      // Leaving the app: upload pending changes now rather than later.
      onHide: _autoBackup.flush,
    );
    final notifications = ref.read(notificationServiceProvider);
    _taps = notifications.taps.listen(_handlePayload);
    final launch = notifications.launchPayload;
    if (launch != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handlePayload(launch),
      );
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _autoBackup.dispose();
    _updates.dispose();
    _syncDebounce?.cancel();
    unawaited(_taps?.cancel());
    super.dispose();
  }

  void _handlePayload(String payload) {
    _log.info('Notification tapped: $payload');
    final router = ref.read(routerProvider);
    if (payload.startsWith('tracker:')) {
      final id = int.tryParse(payload.substring('tracker:'.length));
      if (id != null) router.go(Routes.logTracker(id));
    } else if (payload == 'update') {
      router.go(Routes.home);
      _openUpdateSheetWhenReady();
    } else {
      router.go(Routes.today);
    }
  }

  /// After a cold start the router (and its navigator) only exists once the
  /// splash is gone, so keep trying for a few seconds.
  void _openUpdateSheetWhenReady([int attempt = 0]) {
    if (!mounted) return;
    final context = ref
        .read(routerProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (context != null && context.mounted) {
      showUpdateSheet(context);
    } else if (attempt < 60) {
      Future<void>.delayed(
        const Duration(milliseconds: 150),
        () => _openUpdateSheetWhenReady(attempt + 1),
      );
    }
  }

  /// Reschedules reminders whenever trackers, reminder settings or today's
  /// skips (e.g. "Left office" on a work-from-home day) change.
  void _scheduleReminderSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(ref.read(reminderSyncProvider)());
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<Tracker>>(
      activeTrackersProvider,
      (_, _) => _scheduleReminderSync(),
    );
    ref.listen<(bool, int, bool, int)>(
      settingsValueProvider.select(
        (s) =>
            (s.checkInEnabled, s.checkInMinutes, s.use24h, s.dayStartMinutes),
      ),
      (_, _) => _scheduleReminderSync(),
    );
    ref.listen<String>(
      reminderSkipKeyProvider,
      (_, _) => _scheduleReminderSync(),
    );

    final settingsAsync = ref.watch(settingsProvider);
    final journeyAsync = ref.watch(activeJourneyProvider);
    final settings = settingsAsync.value ?? const AppSettings();
    final ready = settingsAsync.hasValue && journeyAsync.hasValue;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final useDynamic = settings.useDynamicColor;
        final seed = Color(settings.seedColor);
        final light = AppTheme.light(useDynamic ? lightDynamic : null, seed);
        final dark = AppTheme.dark(
          useDynamic ? darkDynamic : null,
          seed,
          pureBlack: settings.pureBlack,
        );
        if (!ready) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: light,
            darkTheme: dark,
            themeMode: settings.themeMode,
            home: const _Splash(),
          );
        }
        return MaterialApp.router(
          title: 'Redemption',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: settings.themeMode,
          routerConfig: ref.watch(routerProvider),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'REDEMPTION',
              style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 6),
            ),
          ],
        ),
      ),
    );
  }
}
