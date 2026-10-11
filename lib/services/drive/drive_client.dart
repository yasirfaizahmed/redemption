import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('DriveClient');

/// A file in the app's private Drive folder.
class DriveFile {
  const DriveFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.modifiedTime,
    this.appProperties = const {},
  });

  factory DriveFile.fromJson(Map<String, dynamic> json) => DriveFile(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    sizeBytes: int.tryParse('${json['size'] ?? ''}') ?? 0,
    modifiedTime:
        DateTime.tryParse(json['modifiedTime'] as String? ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    appProperties: {
      for (final e
          in (json['appProperties'] as Map<String, dynamic>? ?? const {})
              .entries)
        e.key: '${e.value}',
    },
  );

  final String id;
  final String name;
  final int sizeBytes;
  final DateTime modifiedTime;
  final Map<String, String> appProperties;
}

class DriveUser {
  const DriveUser({this.email, this.displayName});
  final String? email;
  final String? displayName;
}

/// HTTP failure from the Drive API.
class DriveApiException implements Exception {
  DriveApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => 'Drive API error $statusCode: $message';
}

/// Supplies OAuth access tokens; [invalidate] drops a token Google rejected.
abstract interface class AccessTokenProvider {
  Future<String?> accessToken();
  Future<void> invalidate(String token);
}

/// Minimal Google Drive v3 REST client scoped to the hidden, app-private
/// `appDataFolder` (scope `drive.appdata`): only this app can see the files,
/// they don't clutter the user's Drive, and they count towards their quota.
class DriveClient {
  DriveClient(this._tokens, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  static const scope = 'https://www.googleapis.com/auth/drive.appdata';
  static const _api = 'https://www.googleapis.com/drive/v3';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3';
  static const _fileFields = 'id,name,size,modifiedTime,appProperties';

  final AccessTokenProvider _tokens;
  final http.Client _http;

  /// Who the files belong to (best effort, used for display only).
  Future<DriveUser> about() async {
    final res = await _send(
      'GET',
      Uri.parse('$_api/about?fields=user(displayName,emailAddress)'),
    );
    final user =
        (jsonDecode(res.body) as Map<String, dynamic>)['user']
            as Map<String, dynamic>?;
    return DriveUser(
      email: user?['emailAddress'] as String?,
      displayName: user?['displayName'] as String?,
    );
  }

  /// Files in appDataFolder, newest first.
  Future<List<DriveFile>> list() async {
    final files = <DriveFile>[];
    String? pageToken;
    do {
      final uri = Uri.parse('$_api/files').replace(
        queryParameters: {
          'spaces': 'appDataFolder',
          'fields': 'nextPageToken,files($_fileFields)',
          'orderBy': 'modifiedTime desc',
          'pageSize': '100',
          'pageToken': ?pageToken,
        },
      );
      final body =
          jsonDecode((await _send('GET', uri)).body) as Map<String, dynamic>;
      files.addAll([
        for (final f in body['files'] as List<dynamic>? ?? const [])
          DriveFile.fromJson(f as Map<String, dynamic>),
      ]);
      pageToken = body['nextPageToken'] as String?;
    } while (pageToken != null);
    return files;
  }

  /// Creates a new file in appDataFolder, or replaces the content of
  /// [existingId]. Uses a resumable session so large photo-heavy backups
  /// upload reliably.
  Future<DriveFile> upload({
    required String name,
    required Uint8List bytes,
    Map<String, String> appProperties = const {},
    String? existingId,
    String mimeType = 'application/zip',
  }) async {
    final metadata = <String, dynamic>{
      'name': name,
      'appProperties': appProperties,
      if (existingId == null) 'parents': ['appDataFolder'],
    };
    final start = existingId == null
        ? Uri.parse('$_upload/files?uploadType=resumable&fields=$_fileFields')
        : Uri.parse(
            '$_upload/files/$existingId?uploadType=resumable&fields=$_fileFields',
          );
    final session = await _send(
      existingId == null ? 'POST' : 'PATCH',
      start,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': mimeType,
        'X-Upload-Content-Length': '${bytes.length}',
      },
      body: utf8.encode(jsonEncode(metadata)),
    );
    final location = session.headers['location'];
    if (location == null) {
      throw DriveApiException(session.statusCode, 'No upload session URL');
    }
    final res = await _send(
      'PUT',
      Uri.parse(location),
      headers: {'Content-Type': mimeType},
      body: bytes,
    );
    final file = DriveFile.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
    _log.info('Uploaded ${file.name} (${bytes.length} bytes)');
    return file;
  }

  Future<Uint8List> download(String fileId) async {
    final res = await _send('GET', Uri.parse('$_api/files/$fileId?alt=media'));
    return res.bodyBytes;
  }

  Future<void> delete(String fileId) async {
    await _send('DELETE', Uri.parse('$_api/files/$fileId'));
  }

  /// Sends an authorised request; on 401 the token is invalidated and the
  /// request retried once with a fresh token.
  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    for (var attempt = 0; ; attempt++) {
      final token = await _tokens.accessToken();
      if (token == null) {
        throw DriveApiException(401, 'Not connected to Google Drive');
      }
      final request = http.Request(method, uri)
        ..headers.addAll({...headers, 'Authorization': 'Bearer $token'});
      if (body != null) request.bodyBytes = body;
      final res = await http.Response.fromStream(await _http.send(request));
      if (res.statusCode == 401 && attempt == 0) {
        _log.info('Access token rejected; refreshing');
        await _tokens.invalidate(token);
        continue;
      }
      if (res.statusCode >= 400) {
        throw DriveApiException(res.statusCode, _errorMessage(res));
      }
      return res;
    }
  }

  static String _errorMessage(http.Response res) {
    try {
      final error =
          (jsonDecode(res.body) as Map<String, dynamic>)['error']
              as Map<String, dynamic>;
      return error['message'] as String? ?? res.reasonPhrase ?? 'error';
    } catch (_) {
      return res.reasonPhrase ?? 'HTTP ${res.statusCode}';
    }
  }

  void close() => _http.close();
}
