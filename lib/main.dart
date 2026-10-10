import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'core/logging/app_logger.dart';
import 'data/db/database.dart';
import 'data/repositories/entry_repository.dart';
import 'data/storage/attachment_store.dart';
import 'services/notification_service.dart';
import 'state/providers.dart';

final _log = Logger('Bootstrap');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.instance.init();

  // Global error capture → structured logs (visible in Settings › Diagnostics).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Logger('Flutter')
        .severe(details.exceptionAsString(), details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    Logger('Uncaught').severe('Uncaught error', error, stack);
    return true;
  };

  final stopwatch = Stopwatch()..start();
  final db = AppDatabase();
  final attachments = await AttachmentStore.open();
  final notifications = NotificationService();
  await notifications.init();
  _log.info(
    'Bootstrapped in ${stopwatch.elapsedMilliseconds} ms '
    '(${kReleaseMode ? 'release' : 'debug'})',
  );

  // Housekeeping off the critical path.
  unawaited(() async {
    try {
      final referenced = await EntryRepository(db).referencedAttachments();
      await attachments.deleteOrphans(referenced);
    } catch (e, s) {
      _log.warning('Attachment cleanup failed', e, s);
    }
  }());

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        attachmentStoreProvider.overrideWithValue(attachments),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const RedemptionApp(),
    ),
  );
}
