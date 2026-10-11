import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:redemption/app/app.dart';
import 'package:redemption/core/time/day.dart';
import 'package:redemption/data/db/database.dart';
import 'package:redemption/data/repositories/journey_repository.dart';
import 'package:redemption/data/repositories/settings_repository.dart';
import 'package:redemption/data/storage/attachment_store.dart';
import 'package:redemption/domain/app_settings.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/state/providers.dart';

/// 10 Oct 2026, 14:30 — journey started on 1 Oct, so it is day 10.
final testNow = DateTime(2026, 10, 10, 14, 30);
const testStart = Day(2026, 10, 1);

class TestEnv {
  TestEnv(this.db, this.dir);
  final AppDatabase db;
  final Directory dir;

  Future<void> dispose() async {
    await db.close();
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}

/// Fresh in-memory database, optionally seeded with a template journey.
Future<TestEnv> createEnv(
  WidgetTester tester, {
  JourneyTemplate? template,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  final dir = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('redemption_widget'),
  ))!;
  if (template != null) {
    await tester.runAsync(() async {
      await SettingsRepository(db)
          .save(const AppSettings(onboardingDone: true));
      await JourneyRepository(db).createFromTemplate(
        template: template,
        name: template.suggestedName,
        intention: template.suggestedIntention,
        startDay: testStart,
        durationDays: 90,
      );
    });
  }
  return TestEnv(db, dir);
}

/// Unmounts the app (cancelling DB stream subscriptions) before closing the DB.
Future<void> disposeEnv(WidgetTester tester, TestEnv env) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.runAsync(env.dispose);
}

/// A phone-sized surface (Pixel-like 393×873 dp).
void usePhoneSurface(WidgetTester tester, {double textScale = 1}) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Widget buildApp(
  TestEnv env, {
  DateTime? now,
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(env.db),
    attachmentStoreProvider.overrideWithValue(AttachmentStore(env.dir)),
    clockProvider.overrideWith(() => FixedClock(now ?? testNow)),
    ...overrides,
  ],
  child: const RedemptionApp(),
);

/// Pumps frames until async DB streams have delivered and animations settle.
Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );
}
