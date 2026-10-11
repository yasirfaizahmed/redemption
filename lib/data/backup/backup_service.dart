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
  Future<void> importFile(File file) async => importBytes(
    await file.readAsBytes(),
    isJson: file.path.toLowerCase().endsWith('.json'),
  );

  /// Restores from backup bytes, replacing ALL data. The archive is fully
  /// validated before anything on the device is touched.
  Future<void> importBytes(List<int> bytes, {bool isJson = false}) async {
    Map<String, dynamic> snapshot;
    final attachments = <String, List<int>>{};
    if (isJson) {
      snapshot = _decode(utf8.decode(bytes));
    } else {
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
      snapshot = _decode(utf8.decode(json.content));
      for (final f in archive.files) {
        if (f.isFile && f.name.startsWith('attachments/')) {
          attachments[f.name.substring('attachments/'.length)] = f.content;
        }
      }
    }
    await restoreSnapshot(snapshot);
    await _attachments.clear();
    for (final e in attachments.entries) {
      final safe = p.normalize(e.key);
      if (safe.startsWith('..') || p.isAbsolute(safe)) continue; // zip-slip
      await _attachments.writeBytes(safe, e.value);
    }
    _log.info('Restored backup with ${attachments.length} attachments');
  }

  Map<String, dynamic> _decode(String text) {
    final data = jsonDecode(text);
    if (data is! Map<String, dynamic> || data['format'] != format) {
      throw BackupException('This file is not a Redemption backup.');
    }
    final version = data['version'] as int? ?? 0;
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
    final buf = StringBuffer()
      ..writeln(
        'date,day_number,tracker,section,type,value,raw,progress,goal_met,note',
      );
    for (final row in entryRows) {
      final e = row.toDomain();
      final t = trackers[e.trackerId];
      if (t == null) continue;
      final progress = scoring.progress(t, e.value);
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
