import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:redemption/data/repositories/entry_repository.dart';
import 'package:redemption/data/repositories/journey_repository.dart';
import 'package:redemption/domain/models.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/domain/tracker_value.dart';
import 'package:redemption/features/today/tracker_tile.dart';

import '../support/harness.dart';

void main() {
  testWidgets('“What did you eat?” is info only: points come from eating on '
      'time', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));

    await tester.pumpWidget(buildApp(env));
    await settle(tester);
    await tester.tap(find.text('Today').last);
    await settle(tester);

    final lunch = find.text('Lunch on time?');
    await tester.dragUntilVisible(
      lunch,
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await settle(tester);
    await tester.tap(lunch);
    await settle(tester);

    // Write what was eaten without answering: saved, but no points.
    await tester.enterText(
      find.widgetWithText(TextField, 'What did you eat?'),
      'Rice, dal',
    );
    await tester.tap(find.text('Save'));
    await settle(tester);

    Future<List<Entry>> entries() async {
      final journey = (await JourneyRepository(env.db).active())!;
      return EntryRepository(env.db).watchForJourney(journey.id).first;
    }

    var entry = (await tester.runAsync(entries))!.single;
    expect(entry.value.isEmpty, isTrue, reason: 'no answer, no points');
    expect(entry.note, 'Rice, dal');
    final tile = find.ancestor(of: lunch, matching: find.byType(TrackerTile));
    expect(
      find.descendant(of: tile, matching: find.textContaining('Rice, dal')),
      findsOneWidget,
    );

    // Eating on time is what earns the points; the info stays.
    await tester.tap(
      find.descendant(of: tile, matching: find.byTooltip('Mark On time')),
    );
    await settle(tester);
    entry = (await tester.runAsync(entries))!.single;
    expect(entry.value, const BoolValue(true));
    expect(entry.note, 'Rice, dal');
    expect(
      find.descendant(of: tile, matching: find.text('On time — Rice, dal')),
      findsOneWidget,
    );
  });
}
