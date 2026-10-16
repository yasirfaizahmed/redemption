import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:redemption/data/repositories/entry_repository.dart';
import 'package:redemption/data/repositories/journey_repository.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/domain/tracker_value.dart';
import 'package:redemption/features/today/tracker_tile.dart';

import '../support/harness.dart';

void main() {
  testWidgets('Workout: one tap logs “Trained” for the points, then a '
      'comment records what was trained', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);

    final mark = find.byTooltip('Mark Trained');
    await tester.dragUntilVisible(
      mark,
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await settle(tester);
    await tester.tap(mark);
    await settle(tester);

    final workoutTile = find.ancestor(
      of: find.text('Workout'),
      matching: find.byType(TrackerTile),
    );
    expect(
      find.descendant(
        of: workoutTile,
        matching: find.text('Trained — tap to add details'),
      ),
      findsOneWidget,
    );

    // The sheet opens with the comment box asking what was trained.
    await tester.tap(find.text('Trained — tap to add details'));
    await settle(tester);
    final comment = find.widgetWithText(TextField, 'What did you train?');
    expect(comment, findsOneWidget);
    await tester.enterText(comment, 'Push day: bench 4×8');
    await tester.tap(find.text('Save'));
    await settle(tester);

    final journey = (await tester.runAsync(
      () => JourneyRepository(env.db).active(),
    ))!;
    final entries = (await tester.runAsync(
      () => EntryRepository(env.db).watchForJourney(journey.id).first,
    ))!;
    final workout = entries.single;
    expect(workout.value, const BoolValue(true));
    expect(workout.note, 'Push day: bench 4×8');
    expect(
      find.descendant(
        of: workoutTile,
        matching: find.text('Trained — Push day: bench 4×8'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('writing what you trained without tapping an answer counts '
      'as Trained', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);
    await tester.dragUntilVisible(
      find.text('Workout'),
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await settle(tester);
    await tester.tap(find.text('Workout'));
    await settle(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'What did you train?'),
      'Legs\n\nSquats 5×5',
    );
    await tester.tap(find.text('Save'));
    await settle(tester);

    final journey = (await tester.runAsync(
      () => JourneyRepository(env.db).active(),
    ))!;
    final entry = (await tester.runAsync(
      () => EntryRepository(env.db).watchForJourney(journey.id).first,
    ))!.single;
    expect(entry.value, const BoolValue(true));
    expect(find.text('Trained — Legs · Squats 5×5'), findsOneWidget);
  });
}
