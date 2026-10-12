import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:redemption/data/repositories/entry_repository.dart';
import 'package:redemption/data/repositories/journey_repository.dart';
import 'package:redemption/features/settings/backup_import.dart';

import '../support/harness.dart';

void main() {
  testWidgets('a fresh install imports a v1.0.0 backup from the welcome '
      'screen and continues where it left off', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester);
    addTearDown(() => disposeEnv(tester, env));
    final bytes = (await tester.runAsync(
      () => File('test/fixtures/redemption-backup-v1.0.0.zip').readAsBytes(),
    ))!;

    await tester.pumpWidget(
      buildApp(
        env,
        overrides: [
          backupFilePickerProvider.overrideWithValue(
            () async => (name: 'redemption-backup.zip', bytes: bytes),
          ),
        ],
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Import a backup file'));
    await settle(tester, rounds: 25);

    expect(find.text('Rewire your brain\nin 90 days.'), findsNothing);
    expect(find.textContaining('Imported 1 journey'), findsOneWidget);
    final journey = (await tester.runAsync(
      () => JourneyRepository(env.db).active(),
    ))!;
    expect(journey.name, 'Redemption — 90 days');
    final entries = (await tester.runAsync(
      () => EntryRepository(env.db).watchForJourney(journey.id).first,
    ))!;
    expect(entries, hasLength(32));
  });

  testWidgets('a file that is not a backup is refused politely', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(
      buildApp(
        env,
        overrides: [
          backupFilePickerProvider.overrideWithValue(
            () async => (name: 'photo.jpg', bytes: [1, 2, 3, 4]),
          ),
        ],
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Import a backup file'));
    await settle(tester, rounds: 10);

    expect(find.text('This file is not a Redemption backup.'), findsOneWidget);
    expect(find.text('Let’s build it'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Let’s build it'),
    );
    expect(button.onPressed, isNotNull, reason: 'busy state is cleared');
  });
}
