import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/time/day.dart';
import '../../domain/app_settings.dart';
import '../../domain/formatting.dart';
import '../../domain/models.dart';
import '../../domain/scoring.dart';
import '../db/database.dart';
import '../repositories/mappers.dart';
import '../storage/attachment_store.dart';

final _log = Logger('BackupService');

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What an import brought in.
class ImportSummary {
  const ImportSummary({
    required this.journeys,
    required this.trackers,
    required this.entries,
    required this.attachments,
    this.exportedAt,
  });

  final int journeys;
  final int trackers;
  final int entries;
  final int attachments;

  /// When the backup was made (null for very old/hand-made files).
  final DateTime? exportedAt;

  String describe() {
    String n(int count, String one, String many) =>
        '$count ${count == 1 ? one : many}';
    return [
      n(journeys, 'journey', 'journeys'),
      n(trackers, 'tracker', 'trackers'),
      n(entries, 'entry', 'entries'),
      if (attachments > 0) n(attachments, 'photo/file', 'photos/files'),
    ].join(' · ');
  }
}

/// Full-fidelity backup (ZIP with JSON + attachments) and CSV export.
class BackupService {
  BackupService(this._db, this._attachments);

  final AppDatabase _db;
  final AttachmentStore _attachments;

  static const format = 'redemption-backup';

  /// Settings that belong to the device, never overwritten by a restore.
  static final deviceSettingKeys = {
    ...AppSettings.driveKeys,
    ...AppSettings.updateKeys,
    'installId',
  };
  static const formatVersion = 1;

  Future<Map<String, dynamic>> buildSnapshot() async {
    final journeys = await _db.select(_db.journeys).get();
    final trackers = await _db.select(_db.trackers).get();
    final entries = await _db.select(_db.entries).get();
    final dashboard = await _db.select(_db.dashboardItems).get();
    final settings = await _db.select(_db.settings).get();
    return {
      'format': format,
      'version': formatVersion,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'settings': {
        for (final s in settings)
          if (!deviceSettingKeys.contains(s.key)) s.key: s.value,
      },
      'journeys': [for (final j in journeys) j.toJson()],
      'trackers': [for (final t in trackers) t.toJson()],
      'entries': [for (final e in entries) e.toJson()],
      'dashboard': [for (final d in dashboard) d.toJson()],
    };
  }

  /// The full backup (data + attachments) as ZIP bytes.
  Future<Uint8List> buildZipBytes() async {
    final snapshot = await buildSnapshot();
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'backup.json',
          const JsonEncoder.withIndent('  ').convert(snapshot),
        ),
      );
    var count = 0;
    await for (final (rel, file) in _attachments.listAll()) {
      archive.addFile(
        ArchiveFile.bytes(
          p.posix.join('attachments', p.split(rel).join('/')),
          await file.readAsBytes(),
        ),
      );
      count++;
    }
    final bytes = ZipEncoder().encodeBytes(archive);
    _log.info('Built backup: ${bytes.length} bytes, $count attachments');
    return bytes;
  }

  /// Writes a `.zip` backup into the temp directory and returns it.
  Future<File> exportZip() async {
    final bytes = await buildZipBytes();
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final out = File(p.join(dir.path, 'redemption-backup-$stamp.zip'));
    await out.writeAsBytes(bytes, flush: true);
    return out;
  }

  /// Restores from a `.zip` (or bare `.json`) backup file, replacing ALL data.
  Future<ImportSummary> importFile(File file) async =>
      importBytes(await file.readAsBytes());

  /// Restores from backup bytes — a ZIP or a bare `backup.json` from any
  /// version of the app, detected by content — replacing ALL data. The
  /// backup is fully parsed and validated before anything is touched, and
  /// the database is replaced in a single transaction.
  Future<ImportSummary> importBytes(List<int> bytes) async {
    Map<String, dynamic> snapshot;
    final attachments = <String, List<int>>{};
    if (_looksLikeZip(bytes)) {
      final Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
      } catch (_) {
        throw BackupException('This file is not a valid Redemption backup.');
      }
      final json = archive.findFile('backup.json');
      if (json == null) {
        throw BackupException('This ZIP is not a Redemption backup.');
      }
      snapshot = _decode(json.content);
      for (final f in archive.files) {
        if (f.isFile && f.name.startsWith('attachments/')) {
          attachments[f.name.substring('attachments/'.length)] = f.content;
        }
      }
    } else {
      snapshot = _decode(bytes);
    }
    // Unpack photos next to the attachment folder *before* touching the
    // database: if that fails (e.g. the phone is full), nothing changed.
    final staging = await _stageAttachments(attachments);
    try {
      await restoreSnapshot(snapshot);
    } on BackupException {
      await _discard(staging);
      rethrow;
    } catch (e, st) {
      // The restore runs in one transaction, so nothing was changed.
      await _discard(staging);
      _log.warning('Backup rows could not be imported', e, st);
      throw BackupException(
        'This backup could not be read, so nothing was changed. ($e)',
      );
    }
    final written = await _swapInAttachments(staging);
    int count(String key) =>
        (snapshot[key] as List<dynamic>? ?? const []).length;
    final summary = ImportSummary(
      journeys: count('journeys'),
      trackers: count('trackers'),
      entries: count('entries'),
      attachments: written,
      exportedAt: snapshot['exportedAt'] is String
          ? DateTime.tryParse(snapshot['exportedAt'] as String)?.toLocal()
          : null,
    );
    _log.info(
      'Imported backup v${snapshot['version']} '
      '(schema ${snapshot['schemaVersion']}): ${summary.describe()}',
    );
    return summary;
  }

  Directory get _stagingDir => Directory('${_attachments.root.path}.importing');

  Future<Directory> _stageAttachments(Map<String, List<int>> files) async {
    final staging = _stagingDir;
    await _discard(staging);
    try {
      await staging.create(recursive: true);
      for (final e in files.entries) {
        final safe = p.normalize(e.key);
        if (safe.startsWith('..') || p.isAbsolute(safe)) continue; // zip-slip
        final target = File(p.join(staging.path, safe));
        await target.parent.create(recursive: true);
        await target.writeAsBytes(e.value, flush: true);
      }
      return staging;
    } catch (e) {
      await _discard(staging);
      throw BackupException(
        'Couldn’t unpack the photos (is the phone out of space?), so nothing '
        'was changed. ($e)',
      );
    }
  }

  /// Replaces the attachment folder with [staging]; returns the file count.
  Future<int> _swapInAttachments(Directory staging) async {
    final root = _attachments.root;
    final old = Directory('${root.path}.old');
    await _discard(old);
    if (root.existsSync()) await root.rename(old.path);
    try {
      await staging.rename(root.path);
    } catch (e) {
      _log.warning('Swapping attachment folders failed, copying: $e');
      await root.create(recursive: true);
      await for (final f in staging.list(recursive: true)) {
        if (f is! File) continue;
        final target = File(
          p.join(root.path, p.relative(f.path, from: staging.path)),
        );
        await target.parent.create(recursive: true);
        await f.copy(target.path);
      }
      await _discard(staging);
    }
    await _discard(old);
    return root.listSync(recursive: true).whereType<File>().length;
  }

  static Future<void> _discard(Directory dir) async {
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (e) {
      _log.fine('Could not delete ${dir.path}: $e');
    }
  }

  static bool _looksLikeZip(List<int> bytes) =>
      bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B; // "PK"

  Map<String, dynamic> _decode(List<int> bytes) {
    final Object? data;
    try {
      data = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    } on FormatException {
      throw BackupException('This file is not a Redemption backup.');
    }
    if (data is! Map<String, dynamic> || data['format'] != format) {
      throw BackupException('This file is not a Redemption backup.');
    }
    final version = (data['version'] as num?)?.toInt() ?? 0;
    if (version > formatVersion) {
      throw BackupException(
        'This backup was made by a newer version of Redemption. '
        'Please update the app first.',
      );
    }
    return data;
  }

  Future<void> restoreSnapshot(Map<String, dynamic> s) async {
    List<Map<String, dynamic>> list(String key) => [
      for (final e in (s[key] as List<dynamic>? ?? const []))
        e as Map<String, dynamic>,
    ];
    await _db.transaction(() async {
      // Device-specific settings (Drive connection, install id) describe this
      // phone, not the data — keep them instead of the backup's copies.
      final keep = await (_db.select(
        _db.settings,
      )..where((r) => r.key.isIn(deviceSettingKeys))).get();
      await _db.delete(_db.entries).go();
      await _db.delete(_db.dashboardItems).go();
      await _db.delete(_db.trackers).go();
      await _db.delete(_db.journeys).go();
      await _db.delete(_db.settings).go();
      await _db.batch((b) {
        b.insertAll(_db.journeys, [
          for (final j in list('journeys')) JourneyRow.fromJson(j),
        ]);
        b.insertAll(_db.trackers, [
          for (final t in list('trackers')) TrackerRow.fromJson(t),
        ]);
        b.insertAll(_db.entries, [
          for (final e in list('entries')) EntryRow.fromJson(e),
        ]);
        b.insertAll(_db.dashboardItems, [
          for (final d in list('dashboard')) DashboardItemRow.fromJson(d),
        ]);
        final settings = s['settings'] as Map<String, dynamic>? ?? const {};
        b.insertAll(_db.settings, [
          for (final e in settings.entries)
            if (!deviceSettingKeys.contains(e.key))
              SettingsCompanion.insert(key: e.key, value: '${e.value}'),
        ]);
        b.insertAll(_db.settings, [
          for (final r in keep)
            SettingsCompanion.insert(key: r.key, value: r.value),
        ]);
      });
    });
  }

  /// One row per logged entry of [journey] — ready for a spreadsheet/pandas.
  Future<File> exportCsv(
    Journey journey, {
    required int dayStartMinutes,
  }) async {
    final trackerRows = await (_db.select(
      _db.trackers,
    )..where((t) => t.journeyId.equals(journey.id))).get();
    final trackers = {for (final t in trackerRows) t.id: t.toDomain()};
    final entryRows =
        await (_db.select(_db.entries)
              ..where((e) => e.trackerId.isIn(trackers.keys))
              ..orderBy([(e) => OrderingTerm.asc(e.day)]))
            .get();
    final scoring = Scoring(dayStartMinutes: dayStartMinutes);
    final byDay = EntryIndex([for (final r in entryRows) r.toDomain()]);
    final buf = StringBuffer()
      ..writeln(
        'date,day_number,tracker,section,type,value,raw,progress,goal_met,note',
      );
    for (final row in entryRows) {
      final e = row.toDomain();
      final t = trackers[e.trackerId];
      if (t == null) continue;
      final progress = scoring.progress(
        t,
        e.value,
        sameDay: byDay.forDay(e.day),
      );
      final raw = scoring.numericValue(t, e.value);
      buf.writeln(
        [
          e.day.key,
          journey.dayNumber(e.day),
          _csv(t.name),
          _csv(t.section),
          t.type.name,
          _csv(Fmt.value(t, e.value)),
          raw ?? '',
          progress.toStringAsFixed(2),
          Scoring.isComplete(progress),
          _csv(e.note),
        ].join(','),
      );
    }
    final dir = await getTemporaryDirectory();
    final name = journey.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
    final out = File(
      p.join(
        dir.path,
        'redemption-$name-${Day.fromDateTime(DateTime.now())}.csv',
      ),
    );
    await out.writeAsString(buf.toString(), flush: true);
    return out;
  }

  static String _csv(String v) {
    if (v.contains(RegExp(r'[",\n\r]'))) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}
