import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:redemption/app/theme/palette.dart';
import 'package:redemption/data/backup/backup_service.dart';
import 'package:redemption/data/db/database.dart';
import 'package:redemption/data/repositories/entry_repository.dart';
import 'package:redemption/data/repositories/journey_repository.dart';
import 'package:redemption/data/repositories/tracker_repository.dart';
import 'package:redemption/data/storage/attachment_store.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/domain/tracker_goal.dart';
import 'package:redemption/domain/tracker_value.dart';
import 'package:redemption/features/settings/settings_screen.dart';
import 'package:redemption/state/drive_sync.dart';

import '../support/fake_drive.dart';
import '../support/harness.dart';

void main() {
  testWidgets('a quit-style Yes/No logs the winning “No” as a green ✗', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    // "Skipped" is the win for this tracker.
    await tester.runAsync(() async {
      final journey = (await JourneyRepository(env.db).active())!;
      final repo = TrackerRepository(env.db);
      final meal = (await repo.forJourney(journey.id))
          .firstWhere((t) => t.name == 'Pre-workout meal');
      await repo.update(meal.copyWith(goal: const BoolGoal(target: false)));
    });

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);

    final markButton = find.byTooltip('Mark Skipped');
    await tester.dragUntilVisible(
      markButton,
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    expect(
      find.descendant(
        of: markButton,
        matching: find.byIcon(Icons.close_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(markButton);
    await settle(tester);

    final journey = (await tester.runAsync(
      () => JourneyRepository(env.db).active(),
    ))!;
    final entries = (await tester.runAsync(
      () => EntryRepository(env.db).watchForJourney(journey.id).first,
    ))!;
    expect(entries.single.value, const BoolValue(false));

    final logged = find.byTooltip('Skipped — tap to change');
    expect(
      find.descendant(of: logged, matching: find.byIcon(Icons.close_rounded)),
      findsOneWidget,
    );
    final button = tester.widget<IconButton>(
      find.ancestor(of: logged, matching: find.byType(IconButton)).first,
    );
    expect(button.style?.backgroundColor?.resolve({}), Palette.success);
  });

  testWidgets('connecting Google Drive from settings uploads a backup', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    final drive = FakeDriveClient();

    await tester.pumpWidget(
      buildApp(
        env,
        overrides: [
          driveAuthProvider.overrideWithValue(FakeDriveAuth()),
          driveClientProvider.overrideWithValue(drive),
        ],
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);

    final connect = find.widgetWithText(FilledButton, 'Connect');
    await tester.scrollUntilVisible(
      connect,
      300,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(connect);
    await settle(tester);
    await tester.tap(connect);
    await settle(tester, rounds: 20);

    expect(drive.files, hasLength(1));
    expect(find.text('me@example.com'), findsOneWidget);
    expect(find.text('Last backup just now'), findsOneWidget);
    expect(find.text('Back up automatically'), findsOneWidget);
  });

  testWidgets('a fresh install can restore its journey from Google Drive', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester);
    addTearDown(() => disposeEnv(tester, env));
    final drive = FakeDriveClient();

    // The old phone's backup.
    await tester.runAsync(() async {
      final old = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      final dir = await Directory.systemTemp.createTemp('redemption_old');
      try {
        await JourneyRepository(old).createFromTemplate(
          template: Templates.redemption,
          name: 'My 90 days',
          intention: 'For Allah',
          startDay: testStart,
          durationDays: 90,
        );
        final bytes = await BackupService(
          old,
          AttachmentStore(dir),
        ).buildZipBytes();
        await drive.upload(
          name: 'redemption-backup-2026-10-09-oldphone.zip',
          bytes: bytes,
          appProperties: {'installId': 'oldphone', 'entries': '1'},
        );
      } finally {
        await old.close();
        await dir.delete(recursive: true);
      }
    });

    await tester.pumpWidget(
      buildApp(
        env,
        overrides: [
          driveAuthProvider.overrideWithValue(FakeDriveAuth()),
          driveClientProvider.overrideWithValue(drive),
        ],
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Restore from Google Drive'));
    await settle(tester, rounds: 10);
    expect(find.text('Pick a snapshot — newest first.'), findsOneWidget);
    await tester.tap(find.textContaining('1 entry'));
    await settle(tester, rounds: 25);

    final journey = await tester.runAsync(
      () => JourneyRepository(env.db).active(),
    );
    expect(journey?.name, 'My 90 days');
    expect(find.text('Rewire your brain\nin 90 days.'), findsNothing);
    expect(find.text('My 90 days'), findsWidgets);
  });
}
