import 'dart:io';

import 'package:logging/logging.dart';
import 'package:open_filex/open_filex.dart';

import 'github_releases.dart';

final _log = Logger('Updates');

/// Hands a downloaded APK to Android's package installer. The user always
/// confirms the install there (and, the first time, allows Redemption to
/// install apps).
abstract interface class ApkInstaller {
  Future<void> install(File apk);
}

class SystemApkInstaller implements ApkInstaller {
  const SystemApkInstaller();

  static const mimeType = 'application/vnd.android.package-archive';

  @override
  Future<void> install(File apk) async {
    final result = await OpenFilex.open(apk.path, type: mimeType);
    _log.info('Installer: ${result.type.name} ${result.message}');
    switch (result.type) {
      case ResultType.done:
        return;
      case ResultType.permissionDenied:
        throw UpdateException(
          'Allow Redemption to install apps (Settings → Apps → Special app '
          'access → Install unknown apps), then try again.',
        );
      case ResultType.fileNotFound:
        throw UpdateException('The downloaded update is gone. Download again.');
      default:
        throw UpdateException('Couldn’t open the installer: ${result.message}');
    }
  }
}

/// The CPU flavour of this build, matching the release's split APK names.
String deviceAbi([String? platformVersion]) {
  final v = platformVersion ?? Platform.version;
  if (v.contains('"android_arm64"')) return 'arm64-v8a';
  if (v.contains('"android_arm"')) return 'armeabi-v7a';
  if (v.contains('"android_x64"')) return 'x86_64';
  return 'universal';
}
