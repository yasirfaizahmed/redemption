import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/app_settings.dart';
import '../services/update/apk_installer.dart';
import '../services/update/app_version.dart';
import '../services/update/github_releases.dart';
import 'providers.dart';

final _log = Logger('Updates');

/// The installed build and where it came from.
class InstalledApp {
  const InstalledApp({required this.version, this.installerStore});

  final AppVersion version;

  /// Package that installed the app (e.g. a browser, a file manager, Play).
  final String? installerStore;

  /// Play installs must be updated by Play (and its policy forbids
  /// self-updates), so the in-app updater stays off for them.
  bool get fromPlayStore => installerStore == 'com.android.vending';
}

final installedAppProvider = FutureProvider<InstalledApp>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return InstalledApp(
    version: AppVersion.tryParse(info.version) ?? const AppVersion(0, 0, 0),
    installerStore: info.installerStore,
  );
});

/// Whether in-app updates apply: Android builds not installed from Play.
final updatesSupportedProvider = FutureProvider<bool>((ref) async {
  if (kIsWeb || !Platform.isAndroid) return false;
  final app = await ref.watch(installedAppProvider.future);
  return !app.fromPlayStore;
});

final gitHubReleasesProvider = Provider<GitHubReleases>((ref) {
  final releases = GitHubReleases();
  ref.onDispose(releases.close);
  return releases;
});

final apkInstallerProvider = Provider<ApkInstaller>(
  (ref) => const SystemApkInstaller(),
);

/// Where downloaded updates are kept (app cache: no storage permission
/// needed, and Android may reclaim it).
final updateDirectoryProvider = FutureProvider<Directory>(
  (ref) async =>
      Directory(p.join((await getTemporaryDirectory()).path, 'updates')),
);

final deviceAbiProvider = Provider<String>((ref) => deviceAbi());

enum UpdatePhase { idle, checking, downloading, installing }

@immutable
class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.current,
    this.latest,
    this.progress,
    this.apk,
    this.error,
    this.dismissed = false,
  });

  final UpdatePhase phase;
  final AppVersion? current;

  /// Newest published release (null until checked, or if there is none).
  final ReleaseInfo? latest;

  /// 0–1 while downloading.
  final double? progress;

  /// Verified download of [latest], ready for the installer.
  final File? apk;

  /// Last failure worth showing; cleared by the next attempt.
  final String? error;

  /// "Later" on the dashboard card: hidden until the app restarts.
  final bool dismissed;

  bool get available =>
      latest != null && current != null && latest!.version > current!;
  bool get readyToInstall => available && apk != null;
  bool get busy => phase != UpdatePhase.idle;

  UpdateState copyWith({
    UpdatePhase? phase,
    AppVersion? current,
    ReleaseInfo? Function()? latest,
    double? Function()? progress,
    File? Function()? apk,
    String? Function()? error,
    bool? dismissed,
  }) => UpdateState(
    phase: phase ?? this.phase,
    current: current ?? this.current,
    latest: latest != null ? latest() : this.latest,
    progress: progress != null ? progress() : this.progress,
    apk: apk != null ? apk() : this.apk,
    error: error != null ? error() : this.error,
    dismissed: dismissed ?? this.dismissed,
  );
}

/// Check → download (verified) → hand to Android's installer.
class UpdateController extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateState();

  GitHubReleases get _releases => ref.read(gitHubReleasesProvider);

  void _emit(UpdateState next) {
    if (ref.mounted) state = next;
  }

  Future<void> _saveSettings(AppSettings Function(AppSettings) change) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.save(change(await repo.load()));
  }

  Future<File?> _fileFor(ReleaseInfo release) async {
    final asset = release.apkFor(ref.read(deviceAbiProvider));
    if (asset == null) return null;
    final dir = await ref.read(updateDirectoryProvider.future);
    return File(p.join(dir.path, asset.name));
  }

  /// Deletes downloads other than [keep] (older versions, partial files).
  Future<void> _cleanUp({File? keep}) async {
    try {
      final dir = await ref.read(updateDirectoryProvider.future);
      if (!dir.existsSync()) return;
      await for (final f in dir.list()) {
        if (f is File && f.path != keep?.path) await f.delete();
      }
    } catch (e) {
      _log.fine('Update clean-up failed: $e');
    }
  }

  /// Asks GitHub for the newest release. Returns true if it is newer than
  /// this build. [quiet] checks (automatic ones) don't surface errors.
  Future<bool> check({bool quiet = false}) async {
    if (state.busy) return state.available;
    _emit(state.copyWith(phase: UpdatePhase.checking, error: () => null));
    try {
      final installed = await ref.read(installedAppProvider.future);
      final latest = await _releases.latest();
      await _saveSettings((s) => s.copyWith(updateLastCheckAt: DateTime.now));
      var next = state.copyWith(
        phase: UpdatePhase.idle,
        current: installed.version,
        latest: () => latest,
        apk: () => null,
        progress: () => null,
      );
      File? existing;
      if (next.available) {
        // A file only exists at its final name once it was fully verified.
        final file = await _fileFor(latest!);
        if (file != null && file.existsSync()) existing = file;
        next = next.copyWith(apk: () => existing);
      }
      await _cleanUp(keep: existing);
      _log.info(
        'Update check: installed ${installed.version}, '
        'latest ${latest?.version ?? 'none'}',
      );
      _emit(next);
      return next.available;
    } on UpdateException catch (e) {
      _emit(
        state.copyWith(
          phase: UpdatePhase.idle,
          error: () => quiet ? null : e.message,
        ),
      );
      return false;
    } catch (e, s) {
      _log.warning('Update check failed', e, s);
      _emit(
        state.copyWith(
          phase: UpdatePhase.idle,
          error: () => quiet ? null : 'Update check failed: $e',
        ),
      );
      return false;
    }
  }

  /// Downloads and verifies the update for this phone. Returns true once it
  /// is ready to install.
  Future<bool> download({bool quiet = false}) async {
    final latest = state.latest;
    if (state.busy || !state.available || latest == null) {
      return state.readyToInstall;
    }
    if (state.apk?.existsSync() ?? false) return true;
    final asset = latest.apkFor(ref.read(deviceAbiProvider));
    final target = await _fileFor(latest);
    if (asset == null || target == null) {
      _emit(state.copyWith(error: () => 'This release has no Android APK.'));
      return false;
    }
    _emit(
      state.copyWith(
        phase: UpdatePhase.downloading,
        progress: () => 0,
        error: () => null,
      ),
    );
    try {
      final sha = await _releases.sha256For(latest, asset);
      if (sha == null) _log.warning('Release has no checksums; size only');
      var shown = -1;
      final file = await _releases.download(
        asset,
        target,
        sha256Hex: sha,
        onProgress: (received, total) {
          if (total <= 0) return;
          final percent = received * 100 ~/ total;
          if (percent == shown) return;
          shown = percent;
          _emit(state.copyWith(progress: () => received / total));
        },
      );
      _emit(
        state.copyWith(
          phase: UpdatePhase.idle,
          apk: () => file,
          progress: () => null,
        ),
      );
      return true;
    } on UpdateException catch (e) {
      _emit(
        state.copyWith(
          phase: UpdatePhase.idle,
          progress: () => null,
          error: () => quiet ? null : e.message,
        ),
      );
      return false;
    } catch (e, s) {
      _log.warning('Update download failed', e, s);
      _emit(
        state.copyWith(
          phase: UpdatePhase.idle,
          progress: () => null,
          error: () => quiet ? null : 'Download failed: $e',
        ),
      );
      return false;
    }
  }

  /// Opens Android's installer for the update, downloading it first if
  /// needed. The user confirms the install there.
  Future<void> install() async {
    if (state.busy) return;
    if (!state.readyToInstall && !await download()) return;
    final apk = state.apk;
    if (apk == null) return;
    if (!apk.existsSync()) {
      // Android reclaimed the cache: fetch it again.
      _emit(state.copyWith(apk: () => null));
      if (!await download()) return;
      return install();
    }
    _emit(state.copyWith(phase: UpdatePhase.installing, error: () => null));
    try {
      await ref.read(apkInstallerProvider).install(state.apk!);
      _emit(state.copyWith(phase: UpdatePhase.idle));
    } on UpdateException catch (e) {
      _emit(state.copyWith(phase: UpdatePhase.idle, error: () => e.message));
    } catch (e, s) {
      _log.warning('Opening the installer failed', e, s);
      _emit(
        state.copyWith(
          phase: UpdatePhase.idle,
          error: () => 'Couldn’t open the installer: $e',
        ),
      );
    }
  }

  /// No more banner or notification for the current latest version.
  Future<void> skip() async {
    final version = state.latest?.version.toString();
    if (version == null) return;
    await _saveSettings((s) => s.copyWith(updateSkippedVersion: version));
    _emit(state.copyWith(dismissed: true));
  }

  void dismiss() => _emit(state.copyWith(dismissed: true));

  Future<void> setAutoCheck(bool enabled) =>
      _saveSettings((s) => s.copyWith(updateAutoCheck: enabled));

  Future<void> setAutoDownload(bool enabled) =>
      _saveSettings((s) => s.copyWith(updateAutoDownload: enabled));
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

/// Checks for updates while the app is used: shortly after start-up and on
/// return to the app (at most every [interval]). A new version is downloaded
/// in the background (if allowed) and announced once with a notification.
class AutoUpdateChecker {
  AutoUpdateChecker(
    this._ref, {
    this.interval = const Duration(hours: 6),
    this.startDelay = const Duration(seconds: 15),
  });

  final WidgetRef _ref;
  final Duration interval;
  final Duration startDelay;

  Timer? _timer;
  bool _disposed = false;
  bool _running = false;
  bool _checkedThisRun = false;

  void start() => _timer = Timer(startDelay, () => unawaited(_maybeCheck()));

  void onResume() {
    if (_timer?.isActive ?? false) return;
    unawaited(_maybeCheck());
  }

  Future<void> _maybeCheck() async {
    if (_disposed || _running) return;
    _running = true;
    try {
      if (!await _ref.read(updatesSupportedProvider.future) || _disposed) {
        return;
      }
      final settings = await _ref.read(settingsRepositoryProvider).load();
      if (_disposed || !settings.updateAutoCheck) return;
      final last = settings.updateLastCheckAt;
      final due =
          !_checkedThisRun ||
          last == null ||
          DateTime.now().difference(last) >= interval;
      if (!due) return;
      _checkedThisRun = true;

      final controller = _ref.read(updateControllerProvider.notifier);
      if (!await controller.check(quiet: true) || _disposed) return;
      final version = _ref.read(updateControllerProvider).latest!.version;
      if ('$version' == settings.updateSkippedVersion) return;

      var ready = _ref.read(updateControllerProvider).readyToInstall;
      if (!ready && settings.updateAutoDownload) {
        ready = await controller.download(quiet: true);
      }
      if (_disposed || '$version' == settings.updateNotifiedVersion) return;
      await _ref
          .read(notificationServiceProvider)
          .showUpdate(version: 'v$version', ready: ready);
      final repo = _ref.read(settingsRepositoryProvider);
      await repo.save(
        (await repo.load()).copyWith(updateNotifiedVersion: '$version'),
      );
    } catch (e, s) {
      _log.warning('Automatic update check failed', e, s);
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
