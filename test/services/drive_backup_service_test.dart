import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redemption/core/time/day.dart';
import 'package:redemption/data/backup/backup_service.dart';
import 'package:redemption/data/db/database.dart';
import 'package:redemption/data/repositories/entry_repository.dart';
import 'package:redemption/data/repositories/journey_repository.dart';
import 'package:redemption/data/repositories/settings_repository.dart';
import 'package:redemption/data/repositories/tracker_repository.dart';
import 'package:redemption/data/storage/attachment_store.dart';
import 'package:redemption/domain/app_settings.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/domain/tracker_value.dart';
import 'package:redemption/services/drive/drive_backup_service.dart';
import 'package:redemption/services/drive/drive_client.dart';
import 'package:redemption/services/drive/google_drive_auth.dart';
import 'package:redemption/state/drive_sync.dart';
import 'package:redemption/state/providers.dart';

import '../support/fake_drive.dart';

AppDatabase _memoryDb() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

const _start = Day(2026, 10, 1);

Future<int> _seed(AppDatabase db) => JourneyRepository(db).createFromTemplate(
  template: Templates.redemption,
  name: '90 Days',
  intention: 'For Allah',
  startDay: _start,
  durationDays: 90,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory dir;
  late BackupService backup;
  late DateTime now;
  late FakeDriveClient drive;

  DriveBackupService service({int keep = 10}) => DriveBackupService(
    client: drive,
    backup: backup,
    db: db,
    keep: keep,
    clock: () => now,
  );

  setUp(() async {
    db = _memoryDb();
    dir = await Directory.systemTemp.createTemp('redemption_drive');
    backup = BackupService(db, AttachmentStore(dir));
    now = DateTime(2026, 10, 10, 9);
    drive = FakeDriveClient(now: () => now);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('never uploads an empty database', () async {
    await expectLater(
      service().backupNow(installId: 'abcdef0123456789'),
      throwsA(isA<DriveBackupException>()),
    );
    expect(drive.files, isEmpty);
  });

  test('one snapshot per install per day, updated in place', () async {
    await _seed(db);
    final s = service();

    final first = await s.backupNow(installId: 'abcdef0123456789');
    now = now.add(const Duration(hours: 8));
    final second = await s.backupNow(
      installId: 'abcdef0123456789',
      lastUploadAt: first.createdAt,
    );

    expect(drive.files, hasLength(1));
    expect(second.file.name, 'redemption-backup-2026-10-10-abcdef01.zip');
    expect(second.journeys, 1);
    expect(second.installId, 'abcdef0123456789');

    now = now.add(const Duration(days: 1));
    await s.backupNow(installId: 'abcdef0123456789');
    expect(drive.files, hasLength(2));
  });

  test(
    'pruning keeps the newest snapshots and every install’s latest',
    () async {
      await _seed(db);
      final s = service(keep: 3);

      for (var i = 0; i < 5; i++) {
        await s.backupNow(installId: 'oldphone00000000');
        now = now.add(const Duration(days: 1));
      }
      expect(drive.files, hasLength(3));

      // A new phone backs up for a few days: the old phone's latest survives.
      for (var i = 0; i < 4; i++) {
        await s.backupNow(installId: 'newphone00000000');
        now = now.add(const Duration(days: 1));
      }
      final remaining = await s.list();
      expect(remaining, hasLength(4));
      expect(
        remaining.where((b) => b.installId == 'oldphone00000000'),
        hasLength(1),
      );
      expect(remaining.first.installId, 'newphone00000000');
    },
  );

  test('a same-day file written elsewhere is never overwritten', () async {
    await _seed(db);
    final s = service();
    final mine = await s.backupNow(installId: 'abcdef0123456789');
    // Another phone with the same id (or this app before Android restored
    // an older database) updates today's file later on.
    now = now.add(const Duration(hours: 3));
    await drive.upload(
      name: mine.file.name,
      bytes: drive.contents[mine.file.id]!,
      existingId: mine.file.id,
      appProperties: mine.file.appProperties,
    );
    now = now.add(const Duration(hours: 1));
    await expectLater(
      s.backupNow(installId: 'abcdef0123456789', lastUploadAt: mine.createdAt),
      throwsA(isA<InstallIdConflict>()),
    );
    expect(drive.files, hasLength(1));
  });

  test('file names tolerate short install ids', () {
    final s = service();
    expect(
      s.fileNameFor(DateTime(2026, 1, 2), 'abc'),
      'redemption-backup-2026-01-02-abc.zip',
    );
    expect(
      s.fileNameFor(DateTime(2026, 1, 2), ''),
      'redemption-backup-2026-01-02-device.zip',
    );
  });

  test(
    'restore brings the data back but keeps this phone’s Drive link',
    () async {
      final journeyId = await _seed(db);
      final tracker = (await TrackerRepository(db).forJourney(journeyId)).first;
      await EntryRepository(db).upsert(
        trackerId: tracker.id,
        day: _start,
        value: const TimeValue(290),
        note: 'alhamdulillah',
      );
      final settings = SettingsRepository(db);
      await settings.save(
        const AppSettings(
          onboardingDone: true,
          successThreshold: 0.9,
          installId: 'oldphone00000000',
          driveConnected: true,
          driveEmail: 'old@example.com',
        ),
      );
      final snapshotJson = await backup.buildSnapshot();
      expect(
        (snapshotJson['settings'] as Map).keys,
        isNot(anyElement(isIn(BackupService.deviceSettingKeys))),
      );
      final snapshot = await service().backupNow(installId: 'oldphone00000000');

      // Simulate a different phone state, then restore.
      await db.delete(db.entries).go();
      await settings.save(
        (await settings.load()).copyWith(
          successThreshold: 0.6,
          installId: 'newphone00000000',
          driveEmail: 'new@example.com',
        ),
      );
      await service().restore(snapshot);

      final restored = await JourneyRepository(db).active();
      final entries = await EntryRepository(db)
          .watchForJourney(restored!.id)
          .first;
      expect(entries.single.note, 'alhamdulillah');
      final after = await settings.load();
      expect(after.successThreshold, 0.9);
      expect(after.installId, 'newphone00000000');
      expect(after.driveEmail, 'new@example.com');
      expect(after.driveConnected, isTrue);
    },
  );

  group('DriveSyncController', () {
    late FakeDriveAuth auth;
    late ProviderContainer container;

    setUp(() {
      auth = FakeDriveAuth();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          attachmentStoreProvider.overrideWithValue(AttachmentStore(dir)),
          driveAuthProvider.overrideWithValue(auth),
          driveClientProvider.overrideWithValue(drive),
        ],
      );
      addTearDown(container.dispose);
    });

    DriveSyncController sync() => container.read(driveSyncProvider.notifier);
    Future<AppSettings> load() =>
        container.read(settingsRepositoryProvider).load();

    test('connect stores the account and backup records progress', () async {
      await _seed(db);
      expect(await sync().backupNow(), isFalse, reason: 'not connected yet');

      final existing = await sync().connect();
      expect(existing, isEmpty);
      var s = await load();
      expect(s.driveConnected, isTrue);
      expect(s.driveEmail, 'me@example.com');
      expect(auth.hint, 'me@example.com');

      expect(await sync().backupNow(), isTrue);
      s = await load();
      expect(s.driveLastBackupAt, isNotNull);
      expect(s.installId, hasLength(16));
      expect(drive.files.values.single.appProperties['installId'], s.installId);
      expect(container.read(driveSyncProvider).lastError, isNull);

      await sync().disconnect();
      s = await load();
      expect(s.driveConnected, isFalse);
      expect(s.driveLastBackupAt, isNull);
    });

    test('an inherited install id starts a new file instead of '
        'overwriting newer data', () async {
      await _seed(db);
      await sync().connect();
      final svc = container.read(driveBackupServiceProvider);
      final today = svc.fileNameFor(DateTime.now(), 'oldphone00000000');
      final theirs = await drive.upload(
        name: today,
        bytes: Uint8List.fromList([1, 2, 3]),
        appProperties: {'installId': 'oldphone00000000'},
      );
      // Android restored an older copy of the database: same id, older stamp.
      final repo = container.read(settingsRepositoryProvider);
      await repo.save(
        (await repo.load()).copyWith(
          installId: 'oldphone00000000',
          driveLastBackupAt: () =>
              theirs.modifiedTime.subtract(const Duration(hours: 6)),
        ),
      );

      expect(await sync().backupNow(), isTrue);
      expect(drive.files, hasLength(2));
      expect(drive.contents[theirs.id], [1, 2, 3], reason: 'left untouched');
      final s = await load();
      expect(s.installId, isNot('oldphone00000000'));
    });

    test('after a restore, uploads go to a new file', () async {
      await _seed(db);
      await sync().connect();
      expect(await sync().backupNow(), isTrue);
      final before = (await sync().listBackups()).single;

      await sync().restore(before);
      var s = await load();
      expect(s.installId, isEmpty);
      expect(s.driveConnected, isTrue);

      expect(await sync().backupNow(), isTrue);
      s = await load();
      expect(drive.files, hasLength(2), reason: 'pre-restore file kept');
      expect(drive.files.containsKey(before.file.id), isTrue);
    });

    test('a canceled reconnect keeps the warning', () async {
      await _seed(db);
      await sync().connect();
      drive.failWith = DriveApiException(401, 'Invalid Credentials');
      await sync().backupNow();
      expect(container.read(driveSyncProvider).needsReconnect, isTrue);

      auth.connectError = DriveConnectException('x', canceled: true);
      await expectLater(
        sync().connect(),
        throwsA(isA<DriveConnectException>()),
      );
      final state = container.read(driveSyncProvider);
      expect(state.needsReconnect, isTrue);
      expect(state.lastError, contains('Reconnect'));
    });

    test('a revoked grant asks the user to reconnect', () async {
      await _seed(db);
      await sync().connect();
      drive.failWith = DriveApiException(401, 'Invalid Credentials');

      expect(await sync().backupNow(), isFalse);
      final state = container.read(driveSyncProvider);
      expect(state.needsReconnect, isTrue);
      expect(state.lastError, contains('Reconnect'));
      expect(state.busy, isFalse);
    });

    test('settings round-trip the Drive fields', () async {
      final at = DateTime.utc(2026, 10, 10, 6, 30);
      final s = AppSettings.fromMap(
        AppSettings(
          installId: 'id',
          driveConnected: true,
          driveEmail: 'a@b.c',
          driveAutoBackup: false,
          driveLastBackupAt: at,
        ).toMap(),
      );
      expect(s.installId, 'id');
      expect(s.driveConnected, isTrue);
      expect(s.driveEmail, 'a@b.c');
      expect(s.driveAutoBackup, isFalse);
      expect(s.driveLastBackupAt, at);
      expect(
        s.copyWith(driveLastBackupAt: () => null).driveLastBackupAt,
        isNull,
      );
    });
  });
}
