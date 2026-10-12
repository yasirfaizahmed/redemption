import 'dart:io';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import '../../data/backup/backup_service.dart';
import '../../data/db/database.dart';
import 'drive_client.dart';

final _log = Logger('DriveBackup');

class DriveBackupException implements Exception {
  DriveBackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Today's file for this install id was written by someone else — another
/// phone that inherited the id (Android device transfer) or this app before
/// Android restored an older copy of its database. Overwriting it would lose
/// newer data, so the caller must continue under a fresh install id.
class InstallIdConflict implements Exception {
  const InstallIdConflict();
}

/// One snapshot stored in Google Drive.
class DriveBackup {
  const DriveBackup(this.file);
  final DriveFile file;

  DateTime get createdAt => file.modifiedTime;
  int get sizeBytes => file.sizeBytes;
  String get device => file.appProperties['device'] ?? '';
  String get installId => file.appProperties['installId'] ?? '';
  int? get entries => int.tryParse(file.appProperties['entries'] ?? '');
  int? get journeys => int.tryParse(file.appProperties['journeys'] ?? '');
}

/// Versioned backups in the app-private Drive folder.
///
/// One file per install per day (`redemption-backup-YYYY-MM-DD-<install>.zip`)
/// is updated in place during the day; older days remain as restore points
/// and only the newest [keep] snapshots are retained.
class DriveBackupService {
  DriveBackupService({
    required this.client,
    required this.backup,
    required this.db,
    this.keep = 10,
    this.keepInstalls = 5,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const prefix = 'redemption-backup-';

  final DriveClient client;
  final BackupService backup;
  final AppDatabase db;
  final int keep;

  /// How many other installs (phones, reinstalls, restores) keep their
  /// newest snapshot beyond [keep].
  final int keepInstalls;
  final DateTime Function() _clock;

  static bool isBackupFile(DriveFile f) =>
      f.name.startsWith(prefix) && f.name.endsWith('.zip');

  String fileNameFor(DateTime time, String installId) {
    final d = time.toLocal();
    final day =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final tag = installId.isEmpty
        ? 'device'
        : installId.substring(0, installId.length.clamp(0, 8));
    return '$prefix$day-$tag.zip';
  }

  /// All snapshots, newest first.
  Future<List<DriveBackup>> list() async {
    final files = (await client.list()).where(isBackupFile).toList()
      ..sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
    return [for (final f in files) DriveBackup(f)];
  }

  Future<({int journeys, int entries})> _counts() async {
    final journeys = db.journeys.id.count();
    final entries = db.entries.id.count();
    final j = await (db.selectOnly(
      db.journeys,
    )..addColumns([journeys])).getSingle();
    final e = await (db.selectOnly(
      db.entries,
    )..addColumns([entries])).getSingle();
    return (journeys: j.read(journeys) ?? 0, entries: e.read(entries) ?? 0);
  }

  /// Uploads the current data as today's snapshot and prunes old ones.
  ///
  /// Refuses to upload an empty database: on a fresh reinstall that would
  /// overwrite a good backup before the user has had a chance to restore it.
  ///
  /// [lastUploadAt] is the Drive time of this install's previous upload;
  /// today's file is only updated in place if nobody else wrote it since,
  /// otherwise [InstallIdConflict] is thrown.
  Future<DriveBackup> backupNow({
    required String installId,
    DateTime? lastUploadAt,
  }) async {
    final watch = Stopwatch()..start();
    final counts = await _counts();
    if (counts.journeys == 0) {
      throw DriveBackupException('Nothing to back up yet.');
    }
    final name = fileNameFor(_clock(), installId);
    final existing = (await client.list()).where(isBackupFile).toList();
    final sameDay = existing.where((f) => f.name == name).firstOrNull;
    if (sameDay != null &&
        (lastUploadAt == null ||
            sameDay.modifiedTime.isAfter(
              lastUploadAt.add(const Duration(seconds: 2)),
            ))) {
      _log.warning(
        '${sameDay.name} was changed elsewhere (${sameDay.modifiedTime}, '
        'ours $lastUploadAt); not overwriting it',
      );
      throw const InstallIdConflict();
    }
    final bytes = await backup.buildZipBytes();
    final file = await client.upload(
      name: name,
      bytes: bytes,
      existingId: sameDay?.id,
      appProperties: {
        'format': '${BackupService.formatVersion}',
        'installId': installId,
        'device': Platform.operatingSystem,
        'journeys': '${counts.journeys}',
        'entries': '${counts.entries}',
      },
    );
    await _prune();
    _log.info(
      'Backed up ${bytes.length} bytes as ${file.name} '
      'in ${watch.elapsedMilliseconds} ms',
    );
    return DriveBackup(file);
  }

  /// Keeps the newest [keep] snapshots, plus the newest snapshot of up to
  /// [keepInstalls] other installs — so a new phone can never prune away the
  /// last backup of the old one.
  Future<void> _prune() async {
    final all = await list();
    final installs = <String>{};
    final keepIds = <String>{};
    var extra = 0;
    for (final (i, b) in all.indexed) {
      final firstOfInstall = installs.add(b.installId);
      if (i < keep) {
        keepIds.add(b.file.id);
      } else if (firstOfInstall && extra < keepInstalls) {
        keepIds.add(b.file.id);
        extra++;
      }
    }
    for (final old in all.where((b) => !keepIds.contains(b.file.id))) {
      try {
        await client.delete(old.file.id);
        _log.info('Pruned old backup ${old.file.name}');
      } catch (e) {
        _log.warning('Could not prune ${old.file.name}: $e');
      }
    }
  }

  /// Downloads [snapshot] and replaces all local data with it.
  Future<void> restore(DriveBackup snapshot) async {
    final bytes = await client.download(snapshot.file.id);
    await backup.importBytes(bytes);
    _log.info('Restored ${snapshot.file.name} (${bytes.length} bytes)');
  }
}
