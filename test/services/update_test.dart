import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redemption/data/backup/backup_service.dart';
import 'package:redemption/data/db/database.dart';
import 'package:redemption/domain/app_settings.dart';
import 'package:redemption/services/update/apk_installer.dart';
import 'package:redemption/services/update/app_version.dart';
import 'package:redemption/services/update/github_releases.dart';
import 'package:redemption/state/app_update.dart';
import 'package:redemption/state/providers.dart';

import '../support/fake_github.dart';

class FakeInstaller implements ApkInstaller {
  final installed = <String>[];
  UpdateException? error;
  @override
  Future<void> install(File apk) async {
    if (error != null) throw error!;
    installed.add(apk.path);
  }
}

AppVersion v(String s) => AppVersion.tryParse(s)!;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('AppVersion', () {
    test('parses tags, build names and pre-releases', () {
      expect(v('v1.2.3'), const AppVersion(1, 2, 3));
      expect(v('1.2'), const AppVersion(1, 2, 0));
      expect(v('1.2.3+45'), const AppVersion(1, 2, 3));
      expect(v('2.0.0-beta.1').preRelease, 'beta.1');
      expect(AppVersion.tryParse('build-12'), isNull);
      expect(AppVersion.tryParse('latest'), isNull);
    });

    test('orders by SemVer', () {
      expect(v('1.10.0') > v('1.9.9'), isTrue);
      expect(v('v1.1.0') > v('1.0.0'), isTrue);
      expect(v('1.2.0') > v('1.2.0-rc.1'), isTrue);
      expect(v('1.2.0-beta.11') > v('1.2.0-beta.2'), isTrue);
      expect(v('1.2.0-beta') > v('1.2.0-alpha'), isTrue);
      expect(v('1.2.3') == v('v1.2.3+9'), isTrue);
      expect(v('1.0.0') > v('1.0.0'), isFalse);
    });
  });

  test('device ABI follows the Dart VM build', () {
    expect(deviceAbi('3.13.5 (stable) on "android_arm64"'), 'arm64-v8a');
    expect(deviceAbi('3.13.5 (stable) on "android_arm"'), 'armeabi-v7a');
    expect(deviceAbi('3.13.5 (stable) on "android_x64"'), 'x86_64');
    expect(deviceAbi('3.13.5 (stable) on "linux_x64"'), 'universal');
  });

  group('ReleaseInfo', () {
    final release = ReleaseInfo.fromJson(FakeGitHub().releaseJson)!;

    test('picks the APK for the phone, else the universal one', () {
      expect(release.version, v('9.9.0'));
      expect(release.apkFor('arm64-v8a')!.name, endsWith('-arm64-v8a.apk'));
      expect(release.apkFor('x86_64')!.name, endsWith('-universal.apk'));
      expect(release.checksums?.name, 'SHA256SUMS.txt');
    });

    test('“What’s new” is plain text from its own section', () {
      expect(
        release.whatsNew,
        '• Faster dashboard with wrapped lines\n• Linked fix',
      );
    });

    test('ignores releases whose tag is not a version', () {
      expect(
        ReleaseInfo.fromJson({...FakeGitHub().releaseJson, 'tag_name': 'x'}),
        isNull,
      );
    });
  });

  group('GitHubReleases', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('upd'));
    tearDown(() => dir.delete(recursive: true));

    test('latest release; none published reads as null', () async {
      final gh = FakeGitHub();
      final releases = GitHubReleases(httpClient: gh.client);
      expect((await releases.latest())!.tag, 'v9.9.0');
      expect(
        gh.requests.single,
        '/repos/yasirfaizahmed/redemption/releases/latest',
      );
      gh.status = 404;
      expect(await releases.latest(), isNull);
      gh.status = 403;
      await expectLater(releases.latest(), throwsA(isA<UpdateException>()));
    });

    test('downloads and verifies against SHA256SUMS.txt', () async {
      final gh = FakeGitHub();
      final releases = GitHubReleases(httpClient: gh.client);
      final release = (await releases.latest())!;
      final asset = release.apkFor('arm64-v8a')!;
      final sha = await releases.sha256For(release, asset);
      final progress = <int>[];
      final file = await releases.download(
        asset,
        File('${dir.path}/${asset.name}'),
        sha256Hex: sha,
        onProgress: (r, _) => progress.add(r),
      );
      expect(await file.readAsBytes(), gh.apkBytes);
      expect(progress.last, gh.apkBytes.length);
    });

    test('a damaged download is discarded', () async {
      final gh = FakeGitHub(corruptChecksums: true);
      final releases = GitHubReleases(httpClient: gh.client);
      final release = (await releases.latest())!;
      final asset = release.apkFor('arm64-v8a')!;
      final target = File('${dir.path}/${asset.name}');
      await expectLater(
        releases.download(
          asset,
          target,
          sha256Hex: await releases.sha256For(release, asset),
        ),
        throwsA(isA<UpdateException>()),
      );
      expect(dir.listSync(), isEmpty, reason: 'no APK and no .part file');
    });
  });

  group('UpdateController', () {
    late AppDatabase db;
    late Directory dir;
    late FakeGitHub gh;
    late FakeInstaller installer;
    late ProviderContainer container;

    ProviderContainer make({String installed = '1.1.0'}) => ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        gitHubReleasesProvider.overrideWithValue(
          GitHubReleases(httpClient: gh.client),
        ),
        installedAppProvider.overrideWith(
          (ref) async => InstalledApp(version: v(installed)),
        ),
        updateDirectoryProvider.overrideWith((ref) async => dir),
        deviceAbiProvider.overrideWithValue('arm64-v8a'),
        apkInstallerProvider.overrideWithValue(installer),
      ],
    );

    setUp(() async {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      dir = await Directory.systemTemp.createTemp('upd');
      gh = FakeGitHub();
      installer = FakeInstaller();
      container = make();
    });

    tearDown(() async {
      container.dispose();
      await db.close();
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    UpdateController ctl() => container.read(updateControllerProvider.notifier);
    UpdateState st() => container.read(updateControllerProvider);

    test('check → download → install', () async {
      expect(await ctl().check(), isTrue);
      expect(st().available, isTrue);
      expect(st().readyToInstall, isFalse);
      final settings = await container.read(settingsRepositoryProvider).load();
      expect(settings.updateLastCheckAt, isNotNull);

      expect(await ctl().download(), isTrue);
      expect(st().apk!.readAsBytesSync(), gh.apkBytes);
      expect(st().apk!.path, endsWith('redemption-v9.9.0-arm64-v8a.apk'));

      await ctl().install();
      expect(installer.installed, [st().apk!.path]);
      expect(st().busy, isFalse);
      expect(st().error, isNull);
    });

    test('a verified download is reused after a restart', () async {
      await ctl().check();
      await ctl().download();
      final apkRequests = gh.requests.where((r) => r.endsWith('.apk')).length;

      container.dispose();
      container = make();
      expect(await ctl().check(), isTrue);
      expect(st().readyToInstall, isTrue);
      await ctl().install();
      expect(
        gh.requests.where((r) => r.endsWith('.apk')).length,
        apkRequests,
        reason: 'no second download',
      );
      expect(installer.installed, hasLength(1));
    });

    test('up to date: nothing offered and old downloads cleaned', () async {
      await ctl().check();
      await ctl().download();
      container.dispose();
      container = make(installed: '9.9.0');

      expect(await ctl().check(), isFalse);
      expect(st().available, isFalse);
      expect(dir.listSync(), isEmpty);
    });

    test('install errors are shown, quiet checks stay quiet', () async {
      gh.status = 500;
      expect(await ctl().check(quiet: true), isFalse);
      expect(st().error, isNull);
      expect(await ctl().check(), isFalse);
      expect(st().error, isNotNull);

      gh.status = 200;
      await ctl().check();
      installer.error = UpdateException('Allow Redemption to install apps');
      await ctl().install();
      expect(st().error, contains('install apps'));
      expect(st().phase, UpdatePhase.idle);
    });

    test('skipping remembers the version', () async {
      await ctl().check();
      await ctl().skip();
      final s = await container.read(settingsRepositoryProvider).load();
      expect(s.updateSkippedVersion, '9.9.0');
      expect(st().dismissed, isTrue);
    });
  });

  test('update settings round-trip and survive a restore', () {
    final at = DateTime.utc(2026, 10, 11, 8);
    final s = AppSettings.fromMap(
      AppSettings(
        updateAutoCheck: false,
        updateAutoDownload: false,
        updateLastCheckAt: at,
        updateSkippedVersion: '1.2.0',
        updateNotifiedVersion: '1.3.0',
      ).toMap(),
    );
    expect(s.updateAutoCheck, isFalse);
    expect(s.updateAutoDownload, isFalse);
    expect(s.updateLastCheckAt, at);
    expect(s.updateSkippedVersion, '1.2.0');
    expect(s.updateNotifiedVersion, '1.3.0');
    expect(
      BackupService.deviceSettingKeys,
      containsAll(AppSettings.updateKeys),
    );
  });
}
