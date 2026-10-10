import 'dart:io';

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
import 'package:redemption/domain/app_settings.dart';
import 'package:redemption/domain/dashboard.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/domain/tracker_type.dart';
import 'package:redemption/domain/tracker_value.dart';

AppDatabase memoryDb() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

void main() {
  // Tests intentionally open several independent in-memory databases.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late JourneyRepository journeys;
  late TrackerRepository trackers;
  late EntryRepository entries;
  late DashboardRepository dashboard;
  const start = Day(2026, 10, 1);

  setUp(() {
    db = memoryDb();
    journeys = JourneyRepository(db);
    trackers = TrackerRepository(db);
    entries = EntryRepository(db);
    dashboard = DashboardRepository(db);
  });

  tearDown(() => db.close());

  Future<int> seed() => journeys.createFromTemplate(
    template: Templates.redemption,
    name: '90 Days',
    intention: 'For Allah',
    startDay: start,
    durationDays: 90,
  );

  test(
    'creating from a template builds trackers and a wired dashboard',
    () async {
      final id = await seed();
      final active = await journeys.active();
      expect(active?.id, id);
      expect(active?.intention, 'For Allah');

      final list = await trackers.forJourney(id);
      expect(list.length, Templates.redemption.trackers.length);
      expect(list.first.name, 'Wake-up time');
      expect(list.every((t) => t.activeFrom == start), isTrue);

      final items = await dashboard.watch(id).first;
      final strip = items.firstWhere(
        (i) => i.kind == DashboardWidgetKind.todayStrip,
      );
      final names = [
        for (final tid in strip.config.trackerIds)
          list.firstWhere((t) => t.id == tid).name,
      ];
      expect(names, ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']);
    },
  );

  test('only one journey is active at a time', () async {
    final first = await seed();
    final second = await journeys.createFromExisting(
      copyFrom: first,
      name: 'Round 2',
      intention: '',
      startDay: start.addDays(90),
      durationDays: 40,
    );
    final all = await journeys.watchAll().first;
    expect(all.where((j) => j.isActive).map((j) => j.id), [second]);
    final copied = await trackers.forJourney(second);
    expect(copied.length, Templates.redemption.trackers.length);
    // Dashboard tracker references are remapped to the copies.
    final items = await dashboard.watch(second).first;
    final copiedIds = copied.map((t) => t.id).toSet();
    for (final i in items) {
      expect(copiedIds.containsAll(i.config.trackerIds), isTrue);
    }
  });

  test('upsert keeps one entry per tracker per day', () async {
    final id = await seed();
    final fajr = (await trackers.forJourney(id))
        .firstWhere((t) => t.name == 'Fajr');
    await entries.upsert(
      trackerId: fajr.id,
      day: start,
      value: const ChoiceValue('late'),
    );
    await entries.upsert(
      trackerId: fajr.id,
      day: start,
      value: const ChoiceValue('jamaah'),
      note: 'Masjid',
    );
    final all = await entries.watchForJourney(id).first;
    expect(all.length, 1);
    expect(all.single.value, const ChoiceValue('jamaah'));
    expect(all.single.note, 'Masjid');
  });

  test('deleting a tracker cascades to its entries', () async {
    final id = await seed();
    final t = (await trackers.forJourney(id)).first;
    await entries.upsert(
      trackerId: t.id,
      day: start,
      value: const TimeValue(290),
    );
    expect(await trackers.entryCount(t.id), 1);
    await trackers.delete(t.id);
    expect(await entries.watchForJourney(id).first, isEmpty);
  });

  test('new trackers are slotted into the timeline by planned time', () async {
    final id = await seed();
    final existing = await trackers.forJourney(id);
    final template = existing.first.copyWith(
      name: 'Qur’an',
      type: TrackerType.counter,
      anchorMinutes: () =>
          5 * 60 + 30, // between Fajr (05:00) and Breakfast (07:30)
    );
    await trackers.insert(template);
    final names = (await trackers.forJourney(id)).map((t) => t.name).toList();
    expect(names.indexOf('Qur’an'), names.indexOf('Fajr') + 1);
  });

  test('archiving stops a tracker counting without losing it', () async {
    final id = await seed();
    final t = (await trackers.forJourney(id)).first;
    await trackers.archive(t.id, start.addDays(10));
    final archived = (await trackers.forJourney(id)).first;
    expect(archived.isArchived, isTrue);
    expect(archived.isActiveOn(start.addDays(9)), isTrue);
    expect(archived.isActiveOn(start.addDays(10)), isFalse);
    await trackers.restore(t.id);
    expect((await trackers.forJourney(id)).first.isArchived, isFalse);
  });

  test('settings persist as key/value pairs', () async {
    final repo = SettingsRepository(db);
    await repo.save(const AppSettings(dayStartMinutes: 240, pureBlack: true));
    final loaded = await repo.load();
    expect(loaded.dayStartMinutes, 240);
    expect(loaded.pureBlack, isTrue);
  });

  test('backup snapshot restores into an empty database', () async {
    final id = await seed();
    final t = (await trackers.forJourney(id)).first;
    await entries.upsert(
      trackerId: t.id,
      day: start,
      value: const TimeValue(290),
      note: 'alhamdulillah',
    );
    await SettingsRepository(db).save(const AppSettings(successThreshold: 0.9));

    final dir = await Directory.systemTemp.createTemp('redemption_test');
    addTearDown(() => dir.delete(recursive: true));
    final snapshot = await BackupService(
      db,
      AttachmentStore(dir),
    ).buildSnapshot();

    final restoredDb = memoryDb();
    addTearDown(restoredDb.close);
    await BackupService(
      restoredDb,
      AttachmentStore(dir),
    ).restoreSnapshot(snapshot);

    final restored = await JourneyRepository(restoredDb).active();
    expect(restored?.name, '90 Days');
    final restoredEntries = await EntryRepository(restoredDb)
        .watchForJourney(restored!.id)
        .first;
    expect(restoredEntries.single.note, 'alhamdulillah');
    expect((await SettingsRepository(restoredDb).load()).successThreshold, 0.9);
    final items = await DashboardRepository(restoredDb)
        .watch(restored.id)
        .first;
    expect(items.length, Templates.redemption.widgets.length);
  });
}
