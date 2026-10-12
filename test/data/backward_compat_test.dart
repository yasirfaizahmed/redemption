import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redemption/core/time/day.dart';
import 'package:redemption/data/backup/backup_service.dart';
import 'package:redemption/data/db/database.dart';
import 'package:redemption/data/repositories/dashboard_repository.dart';
import 'package:redemption/data/repositories/entry_repository.dart';
import 'package:redemption/data/repositories/journey_repository.dart';
import 'package:redemption/data/repositories/settings_repository.dart';
import 'package:redemption/data/repositories/tracker_repository.dart';
import 'package:redemption/data/storage/attachment_store.dart';
import 'package:redemption/domain/models.dart';
import 'package:redemption/domain/scoring.dart';
import 'package:redemption/domain/tracker_goal.dart';
import 'package:redemption/domain/tracker_type.dart';
import 'package:redemption/domain/tracker_value.dart';

/// `test/fixtures/redemption-backup-v1.0.0.zip` was exported by the real
/// v1.0.0 release code (2 days of a Redemption journey with a quit-style
/// Yes/No and photos). These tests keep every future version able to take
/// over that data.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory dir;
  late BackupService backup;
  final fixture = File('test/fixtures/redemption-backup-v1.0.0.zip');
  const start = Day(2026, 10, 10);

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    dir = await Directory.systemTemp.createTemp('compat');
    backup = BackupService(db, AttachmentStore(dir));
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('a v1.0.0 backup imports completely', () async {
    final summary = await backup.importBytes(await fixture.readAsBytes());
    expect(summary.journeys, 1);
    expect(summary.trackers, 16);
    expect(summary.entries, 32);
    expect(summary.attachments, 2);
    expect(summary.describe(), contains('32 entries'));

    final journey = (await JourneyRepository(db).active())!;
    expect(journey.name, 'Redemption — 90 days');
    expect(journey.startDay, start);
    expect(journey.durationDays, 90);

    final trackers = await TrackerRepository(db).forJourney(journey.id);
    expect(trackers, hasLength(16));
    final quit = trackers.firstWhere((t) => t.name == 'Social media');
    expect(quit.goal, const BoolGoal(target: false));
    expect(quit.winAnswer, isFalse);

    final entries = await EntryRepository(db).watchForJourney(journey.id).first;
    expect(entries, hasLength(32));
    expect(entries.map((e) => e.day).toSet(), {start, start.addDays(1)});

    // Photos come back as files the entries point at.
    final photo = entries.firstWhere((e) => e.value is AttachmentsValue);
    final file = (photo.value as AttachmentsValue).files.single;
    expect(File('${dir.path}/${file.relativePath}').existsSync(), isTrue);

    final settings = await SettingsRepository(db).load();
    expect(settings.onboardingDone, isTrue);
    expect(settings.dayStartMinutes, 240);
    expect(settings.use24h, isFalse);
    expect(settings.successThreshold, 0.8);
    // Settings added after v1.0.0 start from their defaults.
    expect(settings.driveConnected, isFalse);
    expect(settings.updateAutoCheck, isTrue);

    final dashboard = await DashboardRepository(db).watch(journey.id).first;
    expect(dashboard, hasLength(11));
  });

  test('every v1.0.0 entry scores and logging continues on day 3', () async {
    await backup.importBytes(await fixture.readAsBytes());
    final journey = (await JourneyRepository(db).active())!;
    final trackers = await TrackerRepository(db).forJourney(journey.id);
    final repo = EntryRepository(db);
    const scoring = Scoring(dayStartMinutes: 240);

    var entries = await repo.watchForJourney(journey.id).first;
    for (final d in [start, start.addDays(1)]) {
      final summary = scoring.summarize(d, trackers, EntryIndex(entries));
      expect(summary.logged, greaterThan(10));
      expect(summary.score, inInclusiveRange(0.0, 1.0));
    }

    // Day 3 on the new version, on top of the old data.
    final fajr = trackers.firstWhere((t) => t.name == 'Fajr');
    await repo.upsert(
      trackerId: fajr.id,
      day: start.addDays(2),
      value: const ChoiceValue('jamaah'),
    );
    entries = await repo.watchForJourney(journey.id).first;
    expect(entries, hasLength(33));
    expect(
      scoring.status(fajr, entries.last, start.addDays(2), start.addDays(2)),
      EntryStatus.done,
    );
  });

  test('a v1.0.0 export re-imports after new-version changes', () async {
    await backup.importBytes(await fixture.readAsBytes());
    final journey = (await JourneyRepository(db).active())!;
    final text = (await TrackerRepository(db).forJourney(journey.id))
        .firstWhere((t) => t.type == TrackerType.longText);
    await EntryRepository(db).upsert(
      trackerId: text.id,
      day: start.addDays(2),
      value: const TextValue('day 3'),
    );
    final again = await backup.importBytes(await backup.buildZipBytes());
    expect(again.entries, 33);
    expect(again.attachments, 2);
    expect(Directory('${dir.path}.importing').existsSync(), isFalse);
    expect(Directory('${dir.path}.old').existsSync(), isFalse);
  });

  test('the bare backup.json of a v1.0.0 ZIP imports too', () async {
    final archive = ZipDecoder().decodeBytes(await fixture.readAsBytes());
    final json = archive.findFile('backup.json')!.content;
    final summary = await backup.importBytes(json);
    expect(summary.entries, 32);
    expect(summary.attachments, 0);
  });

  test('non-backups are refused without touching data', () async {
    await backup.importBytes(await fixture.readAsBytes());
    await expectLater(
      backup.importBytes(utf8.encode('{"hello": 1}')),
      throwsA(isA<BackupException>()),
    );
    await expectLater(
      backup.importBytes(utf8.encode('not json at all')),
      throwsA(isA<BackupException>()),
    );
    final broken = jsonEncode({
      'format': 'redemption-backup',
      'version': 1,
      'journeys': [
        {'id': 'nope'},
      ],
    });
    await expectLater(
      backup.importBytes(utf8.encode(broken)),
      throwsA(isA<BackupException>()),
    );
    final entries = await EntryRepository(db)
        .watchForJourney((await JourneyRepository(db).active())!.id)
        .first;
    expect(entries, hasLength(32), reason: 'failed imports change nothing');
    expect(
      File('${dir.path}/img_day0.png').existsSync(),
      isTrue,
      reason: 'photos survive a failed import',
    );
  });
}
