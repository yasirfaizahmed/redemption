import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../domain/app_settings.dart';
import '../services/drive/drive_backup_service.dart';
import '../services/drive/drive_client.dart';
import '../services/drive/google_drive_auth.dart';
import 'providers.dart';

final _log = Logger('DriveSync');

final driveAuthProvider = Provider<DriveAuth>((ref) => GoogleDriveAuth());

final driveClientProvider = Provider<DriveClient>((ref) {
  final client = DriveClient(ref.watch(driveAuthProvider));
  ref.onDispose(client.close);
  return client;
});

final driveBackupServiceProvider = Provider(
  (ref) => DriveBackupService(
    client: ref.watch(driveClientProvider),
    backup: ref.watch(backupServiceProvider),
    db: ref.watch(databaseProvider),
  ),
);

enum DrivePhase { idle, connecting, backingUp, restoring }

class DriveSyncState {
  const DriveSyncState({
    this.phase = DrivePhase.idle,
    this.lastError,
    this.needsReconnect = false,
  });

  final DrivePhase phase;

  /// Last failure worth showing, cleared on the next success.
  final String? lastError;

  /// Google refused the stored authorization; the user must reconnect.
  final bool needsReconnect;

  bool get busy => phase != DrivePhase.idle;
}

/// Connect / back up / restore orchestration for Google Drive backups.
class DriveSyncController extends Notifier<DriveSyncState> {
  @override
  DriveSyncState build() => const DriveSyncState();

  DriveAuth get _auth => ref.read(driveAuthProvider);
  DriveBackupService get _service => ref.read(driveBackupServiceProvider);

  Future<AppSettings> _load() => ref.read(settingsRepositoryProvider).load();

  /// Loads settings and points token requests at the connected account.
  Future<AppSettings> _prepare() async {
    final s = await _load();
    _auth.accountHint = s.driveEmail;
    return s;
  }

  Future<void> _update(AppSettings Function(AppSettings) change) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.save(change(await repo.load()));
  }

  void _set(DrivePhase phase, {String? error, bool needsReconnect = false}) {
    if (!ref.mounted) return;
    state = DriveSyncState(
      phase: phase,
      lastError: error,
      needsReconnect: needsReconnect,
    );
  }

  /// A stable random id for this installation (tags its Drive snapshots).
  Future<String> _installId() async {
    final s = await _load();
    if (s.installId.length >= 8) return s.installId;
    final rnd = Random.secure();
    final id = List.generate(
      16,
      (_) => rnd.nextInt(16).toRadixString(16),
    ).join();
    await _update((s) => s.copyWith(installId: id));
    return id;
  }

  /// Interactive: asks for Drive access, then returns the existing backups
  /// (so the caller can offer a restore). Throws [DriveConnectException].
  Future<List<DriveBackup>> connect() async {
    _set(DrivePhase.connecting);
    try {
      await _auth.connect();
      String email = '';
      try {
        email = (await ref.read(driveClientProvider).about()).email ?? '';
      } catch (e) {
        _log.fine('Could not read Drive account: $e');
      }
      _auth.accountHint = email;
      await _update((s) => s.copyWith(driveConnected: true, driveEmail: email));
      final backups = await _service.list();
      _log.info('Connected to Drive (${backups.length} backups found)');
      _set(DrivePhase.idle);
      return backups;
    } on DriveConnectException catch (e) {
      _set(DrivePhase.idle, error: e.canceled ? null : e.message);
      rethrow;
    } on DriveApiException catch (e) {
      final message = _describe(e);
      _set(DrivePhase.idle, error: message);
      throw DriveConnectException(message);
    } catch (e, s) {
      _log.warning('Connect failed', e, s);
      const message = 'Couldn’t reach Google Drive. Check your connection.';
      _set(DrivePhase.idle, error: message);
      throw DriveConnectException(message);
    }
  }

  /// Backs up now. Returns true on success. [auto] runs stay quiet when
  /// there is nothing to do.
  Future<bool> backupNow({bool auto = false}) async {
    if (state.busy) return false;
    _set(DrivePhase.backingUp);
    try {
      final settings = await _prepare();
      if (!settings.driveConnected || !_auth.isSupported) {
        _set(DrivePhase.idle);
        return false;
      }
      await _service.backupNow(installId: await _installId());
      await _update((s) => s.copyWith(driveLastBackupAt: DateTime.now));
      _set(DrivePhase.idle);
      return true;
    } on DriveBackupException catch (e) {
      _set(DrivePhase.idle, error: auto ? null : e.message);
      return false;
    } on DriveApiException catch (e) {
      _log.warning('Backup failed: $e');
      _set(
        DrivePhase.idle,
        error: _describe(e),
        needsReconnect: e.isUnauthorized || e.isForbidden,
      );
      return false;
    } catch (e, s) {
      _log.warning('Backup failed', e, s);
      _set(
        DrivePhase.idle,
        error: 'Backup failed — will retry. (${e.runtimeType})',
      );
      return false;
    }
  }

  Future<List<DriveBackup>> listBackups() async {
    await _prepare();
    return _service.list();
  }

  /// Replaces all local data with [snapshot].
  Future<void> restore(DriveBackup snapshot) async {
    if (state.busy) {
      throw DriveBackupException(
        'Google Drive is busy — try again in a moment.',
      );
    }
    _set(DrivePhase.restoring);
    try {
      await _prepare();
      await _service.restore(snapshot);
      await _update(
        (s) => s.copyWith(
          driveConnected: true,
          driveLastBackupAt: () => snapshot.createdAt,
        ),
      );
      _set(DrivePhase.idle);
    } catch (e, s) {
      _log.warning('Restore failed', e, s);
      _set(
        DrivePhase.idle,
        error: e is DriveApiException ? _describe(e) : 'Restore failed: $e',
      );
      rethrow;
    }
  }

  Future<void> setAutoBackup(bool enabled) =>
      _update((s) => s.copyWith(driveAutoBackup: enabled));

  Future<void> disconnect() async {
    await _auth.disconnect();
    await _update(
      (s) => s.copyWith(
        driveConnected: false,
        driveEmail: '',
        driveLastBackupAt: () => null,
      ),
    );
    _set(DrivePhase.idle);
  }

  static String _describe(DriveApiException e) {
    if (e.isUnauthorized) {
      return 'Google access expired. Tap “Reconnect” to continue backing up.';
    }
    if (e.isForbidden) {
      return e.message.contains('storageQuota') ||
              e.message.toLowerCase().contains('quota')
          ? 'Your Google Drive storage is full.'
          : 'Google Drive refused the request: ${e.message}';
    }
    return 'Google Drive error ${e.statusCode}: ${e.message}';
  }
}

final driveSyncProvider = NotifierProvider<DriveSyncController, DriveSyncState>(
  DriveSyncController.new,
);

/// Backs up automatically while the app is used: a couple of minutes after
/// the last change, when the app goes to the background with unsaved
/// changes, and at start-up if the last backup is old.
class DriveAutoBackup {
  DriveAutoBackup(
    this._ref, {
    this.debounce = const Duration(minutes: 2),
    this.staleAfter = const Duration(hours: 12),
  });

  final WidgetRef _ref;
  final Duration debounce;
  final Duration staleAfter;

  StreamSubscription<void>? _changes;
  Timer? _timer;
  bool _dirty = false;
  bool _disposed = false;

  /// Bumped on every change, so a backup only clears [_dirty] if nothing
  /// changed while it was uploading.
  int _generation = 0;

  void start() {
    final db = _ref.read(databaseProvider);
    _changes = db
        .tableUpdates()
        // Settings-only writes (incl. our own "last backup" stamp) don't
        // need a backup of their own.
        .where((updates) => updates.any((u) => u.table != 'settings'))
        .listen((_) {
          if (!_enabled(_ref.read(settingsValueProvider))) return;
          _generation++;
          _dirty = true;
          _schedule(debounce);
        });
    unawaited(_checkStale());
  }

  Future<void> _checkStale() async {
    final s = await _ref.read(settingsRepositoryProvider).load();
    if (_disposed || !_enabled(s)) return;
    final last = s.driveLastBackupAt;
    if (last == null || DateTime.now().difference(last) > staleAfter) {
      _dirty = true;
      _schedule(const Duration(seconds: 30));
    }
  }

  /// Called when the app goes to the background: back up pending changes
  /// right away instead of waiting for the debounce.
  void flush() {
    if (_dirty && !_disposed) _schedule(Duration.zero);
  }

  bool _enabled(AppSettings s) =>
      s.driveConnected &&
      s.driveAutoBackup &&
      _ref.read(driveAuthProvider).isSupported;

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(_run()));
  }

  Future<void> _run() async {
    try {
      final s = await _ref.read(settingsRepositoryProvider).load();
      if (_disposed || !_enabled(s)) return;
      final generation = _generation;
      final ok = await _ref
          .read(driveSyncProvider.notifier)
          .backupNow(auto: true);
      if (ok && generation == _generation) _dirty = false;
    } catch (e, s) {
      _log.warning('Auto-backup failed', e, s);
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_changes?.cancel());
  }
}
