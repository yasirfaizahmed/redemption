import 'dart:io';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/features/settings/settings_screen.dart';
import 'package:redemption/services/update/apk_installer.dart';
import 'package:redemption/services/update/app_version.dart';
import 'package:redemption/services/update/github_releases.dart';
import 'package:redemption/state/app_update.dart';

import '../support/fake_github.dart';
import '../support/harness.dart';

class _Installer implements ApkInstaller {
  final installed = <String>[];
  @override
  Future<void> install(File apk) async => installed.add(apk.path);
}

void main() {
  late Directory updates;

  setUp(() async => updates = await Directory.systemTemp.createTemp('upd'));
  tearDown(() => updates.delete(recursive: true));

  List<Override> overridesFor(FakeGitHub gh, _Installer installer) => [
    updatesSupportedProvider.overrideWith((ref) async => true),
    installedAppProvider.overrideWith(
      (ref) async => const InstalledApp(version: AppVersion(1, 1, 0)),
    ),
    gitHubReleasesProvider.overrideWithValue(
      GitHubReleases(httpClient: gh.client),
    ),
    updateDirectoryProvider.overrideWith((ref) async => updates),
    deviceAbiProvider.overrideWithValue('arm64-v8a'),
    apkInstallerProvider.overrideWithValue(installer),
  ];

  testWidgets('a new release is fetched in the background and installed '
      'from the dashboard', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    final gh = FakeGitHub();
    final installer = _Installer();

    await tester.pumpWidget(
      buildApp(env, overrides: overridesFor(gh, installer)),
    );
    await settle(tester);
    expect(find.text('Update ready: v9.9.0'), findsNothing);

    // The automatic check runs shortly after start-up.
    await tester.pump(const Duration(seconds: 16));
    await settle(tester, rounds: 20);
    expect(find.text('Update ready: v9.9.0'), findsOneWidget);

    await tester.tap(find.text('Update ready: v9.9.0'));
    await settle(tester);
    expect(find.text('Redemption v9.9.0'), findsOneWidget);
    expect(find.textContaining('Faster dashboard'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Install'));
    await settle(tester);
    expect(installer.installed.single, endsWith('-arm64-v8a.apk'));
  });

  testWidgets('settings can check for updates on demand', (tester) async {
    usePhoneSurface(tester);
    final env = await createEnv(tester, template: Templates.redemption);
    addTearDown(() => disposeEnv(tester, env));
    final gh = FakeGitHub(tag: 'v1.1.0'); // same as installed
    final installer = _Installer();

    await tester.pumpWidget(
      buildApp(env, overrides: overridesFor(gh, installer)),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);

    final check = find.text('Check for updates');
    await tester.scrollUntilVisible(
      check,
      300,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(check);
    await settle(tester);
    await tester.tap(check);
    await settle(tester, rounds: 10);

    expect(find.text('You’re on the latest version (v1.1.0).'), findsOneWidget);
    expect(installer.installed, isEmpty);
  });
}
