import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:redemption/core/time/day.dart';
import 'package:redemption/data/backup/backup_service.dart';
import 'package:redemption/data/repositories/entry_repository.dart';
import 'package:redemption/data/repositories/journey_repository.dart';
import 'package:redemption/data/repositories/tracker_repository.dart';
import 'package:redemption/data/storage/attachment_store.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/domain/tracker_type.dart';
import 'package:redemption/domain/tracker_value.dart';
import 'package:redemption/features/today/tracker_tile.dart';

import '../support/harness.dart';

void main() {
  testWidgets('on an office day Dhuhr drops the congregation button and '
      'praying on time completes it', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    const today = Day(2026, 10, 10);
    late int dhuhrId;
    await tester.runAsync(() async {
      final journey = (await JourneyRepository(env.db).active())!;
      final trackers = await TrackerRepository(env.db).forJourney(journey.id);
      final work = trackers.firstWhere((t) => t.name == 'WFH or office?');
      dhuhrId = trackers.firstWhere((t) => t.name == 'Dhuhr').id;
      await EntryRepository(env.db).upsert(
        trackerId: work.id,
        day: today,
        value: const ChoiceValue('office'),
      );
    });

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);

    final dhuhrTile = find.ancestor(
      of: find.text('Dhuhr'),
      matching: find.byType(TrackerTile),
    );
    await tester.dragUntilVisible(
      find.text('Dhuhr'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await settle(tester);
    expect(
      find.descendant(
        of: dhuhrTile,
        matching: find.textContaining('Office day — no masjid'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dhuhrTile,
        matching: find.byTooltip('In congregation'),
      ),
      findsNothing,
    );
    final onTime = find.descendant(
      of: dhuhrTile,
      matching: find.byTooltip('On time'),
    );
    expect(onTime, findsOneWidget);
    await tester.tap(onTime);
    await settle(tester);

    final entries = (await tester.runAsync(
      () => EntryRepository(env.db).watchForJourney(1).first,
    ))!;
    expect(
      entries.firstWhere((e) => e.trackerId == dhuhrId).value,
      const ChoiceValue('ontime'),
    );
  });

  testWidgets('a v1.0.0 journey is offered the new office-day and meal '
      'checks once', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester);
    addTearDown(() => disposeEnv(tester, env));
    await tester.runAsync(() async {
      await BackupService(env.db, AttachmentStore(env.dir)).importBytes(
        await File('test/fixtures/redemption-backup-v1.0.0.zip').readAsBytes(),
      );
    });

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    expect(find.text('New for your journey'), findsOneWidget);
    expect(find.textContaining('Dhuhr, Asr & Maghrib'), findsOneWidget);
    expect(find.textContaining('Breakfast, Lunch & Dinner'), findsOneWidget);
    expect(
      find.textContaining('Workout becomes “Did you train?”'),
      findsOneWidget,
    );

    expect(find.textContaining('What did you eat?'), findsOneWidget);
    expect(
      find.textContaining(
        'Left office: switches itself off when you work from home or are on '
        'leave',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Add to my journey'));
    await settle(tester);
    await tester.tap(find.text('Add to my journey'));
    await settle(tester, rounds: 12);

    expect(find.text('New for your journey'), findsNothing);
    final trackers = (await tester.runAsync(() async {
      final journey = (await JourneyRepository(env.db).active())!;
      return TrackerRepository(env.db).forJourney(journey.id);
    }))!;
    expect(
      trackers.map((t) => t.name),
      containsAll(['Breakfast on time?', 'Lunch on time?', 'Dinner on time?']),
    );
    expect(
      trackers.firstWhere((t) => t.name == 'Maghrib').config.dayRule,
      isNotNull,
    );
    expect(
      trackers.firstWhere((t) => t.name == 'Workout').type,
      TrackerType.checkbox,
    );
    // Meal texts stop counting; the on-time checks carry what was eaten.
    expect(trackers.firstWhere((t) => t.name == 'Lunch').isArchived, isTrue);
    expect(
      trackers.firstWhere((t) => t.name == 'Lunch on time?').config.notePrompt,
      'What did you eat?',
    );
    expect(
      trackers.firstWhere((t) => t.name == 'Left office').config.skipRule,
      isNotNull,
    );
  });
}
