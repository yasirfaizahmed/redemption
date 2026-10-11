import 'dart:typed_data';

import 'package:redemption/services/drive/drive_client.dart';
import 'package:redemption/services/drive/google_drive_auth.dart';

/// In-memory stand-in for the app's Drive folder.
class FakeDriveClient implements DriveClient {
  FakeDriveClient({DateTime Function()? now, this.email = 'me@example.com'})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final String email;
  final files = <String, DriveFile>{};
  final contents = <String, Uint8List>{};
  int _ids = 0;

  /// When set, every call fails with this error.
  DriveApiException? failWith;

  void _check() {
    if (failWith != null) throw failWith!;
  }

  @override
  Future<DriveUser> about() async {
    _check();
    return DriveUser(email: email);
  }

  @override
  Future<List<DriveFile>> list() async {
    _check();
    return files.values.toList()
      ..sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
  }

  @override
  Future<DriveFile> upload({
    required String name,
    required Uint8List bytes,
    Map<String, String> appProperties = const {},
    String? existingId,
    String mimeType = 'application/zip',
  }) async {
    _check();
    final id = existingId ?? 'file${++_ids}';
    final file = DriveFile(
      id: id,
      name: name,
      sizeBytes: bytes.length,
      modifiedTime: _now(),
      appProperties: appProperties,
    );
    files[id] = file;
    contents[id] = bytes;
    return file;
  }

  @override
  Future<Uint8List> download(String fileId) async {
    _check();
    return contents[fileId]!;
  }

  @override
  Future<void> delete(String fileId) async {
    _check();
    files.remove(fileId);
    contents.remove(fileId);
  }

  @override
  void close() {}
}

class FakeDriveAuth implements DriveAuth {
  FakeDriveAuth({this.isSupported = true});

  @override
  final bool isSupported;

  bool connected = false;
  int connects = 0;
  String? hint;

  /// When set, [connect] throws it.
  DriveConnectException? connectError;

  @override
  set accountHint(String? email) => hint = email;

  @override
  Future<void> connect() async {
    connects++;
    if (connectError != null) throw connectError!;
    connected = true;
  }

  @override
  Future<void> disconnect() async => connected = false;

  @override
  Future<String?> accessToken() async => connected ? 'token' : null;

  @override
  Future<void> invalidate(String token) async {}
}
