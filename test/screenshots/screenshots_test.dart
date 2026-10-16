// Renders real-font screenshots of every main screen into docs/screenshots.
//
//   SCREENSHOTS=1 flutter test test/screenshots --update-goldens
//
// Skipped in normal test runs (font rendering differs slightly by host).
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:redemption/core/time/day.dart';
import 'package:redemption/data/db/database.dart';
import 'package:redemption/domain/app_settings.dart';

import '../support/demo_data.dart';
import '../support/harness.dart';

final _enabled = Platform.environment['SCREENSHOTS'] == '1';
final _now = DateTime(2026, 10, 24, 14, 32);

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? '/opt/sdk/flutter';
  await load('Manrope', [
    for (final w in [
      '400Regular',
      '500Medium',
      '600SemiBold',
      '700Bold',
      '800ExtraBold',
    ])
      'assets/fonts/Manrope_$w.ttf',
  ]);
  await load('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
  const emoji = '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf';
  if (File(emoji).existsSync()) await load('NotoColorEmoji', [emoji]);
}

Future<TestEnv> _demoEnv(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.light,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  final dir = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('shots'),
  ))!;
  await tester.runAsync(
    () => seedDemoJourney(
      db,
      today: Day.fromDateTime(_now),
      nowMinutes: _now.hour * 60 + _now.minute,
      settings: AppSettings(onboardingDone: true, themeMode: mode),
    ),
  );
  return TestEnv(db, dir);
}

Future<void> _shot(WidgetTester tester, String name) async {
  await settle(tester);
  await expectLater(
    find.byType(MaterialApp).first,
    matchesGoldenFile('../../docs/screenshots/$name.png'),
  );
}

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  testWidgets('onboarding', skip: !_enabled, (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester);
    addTearDown(() => disposeEnv(tester, env));
    await tester.pumpWidget(buildApp(env, now: _now));
    await _shot(tester, '01_onboarding');
    await tester.tap(find.text('Let’s build it'));
    await _shot(tester, '02_templates');
  });

  testWidgets('main screens (light)', skip: !_enabled, (tester) async {
    usePhoneSurface(tester);
    final env = await _demoEnv(tester);
    addTearDown(() => disposeEnv(tester, env));
    await tester.pumpWidget(buildApp(env, now: _now));

    await _shot(tester, '03_dashboard');
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await _shot(tester, '04_dashboard_more');
    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await _shot(tester, '05_dashboard_more2');

    await tester.tap(find.text('Today').last);
    await _shot(tester, '06_today');

    Future<void> openSheet(String name, String shot) async {
      await tester.dragUntilVisible(
        find.text(name),
        find.byType(CustomScrollView),
        const Offset(0, -250),
      );
      await settle(tester);
      await tester.tap(find.text(name));
      await _shot(tester, shot);
      await tester.tapAt(const Offset(200, 40));
      await settle(tester);
    }

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await _shot(tester, '06b_today_pending');
    await openSheet('Isha', '07_sheet_prayer');
    await openSheet('Sleep time', '08_sheet_time');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
    await settle(tester);
    await openSheet('Breakfast on time?', '09_sheet_text');

    await tester.tap(find.text('Insights').last);
    await _shot(tester, '10_insights');
    await tester.tap(find.text('Trackers'));
    await _shot(tester, '11_insights_trackers');
    await tester.dragUntilVisible(
      find.text('Wake-up time'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await settle(tester);
    await tester.tap(find.text('Wake-up time'));
    await _shot(tester, '12_tracker_detail');

    await tester.tap(find.text('Plan').last);
    await _shot(tester, '13_plan');
    await tester.tap(find.text('Fajr'));
    await _shot(tester, '14_tracker_editor');
  });

  testWidgets('dark mode', skip: !_enabled, (tester) async {
    usePhoneSurface(tester);
    final env = await _demoEnv(tester, mode: ThemeMode.dark);
    addTearDown(() => disposeEnv(tester, env));
    await tester.pumpWidget(buildApp(env, now: _now));
    await _shot(tester, '15_dashboard_dark');
    await tester.tap(find.text('Today').last);
    await _shot(tester, '16_today_dark');
  });
}
