import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redemption/services/drive/drive_client.dart';

class _Tokens implements AccessTokenProvider {
  _Tokens(this.tokens);
  final List<String?> tokens;
  final invalidated = <String>[];
  int _i = 0;

  @override
  Future<String?> accessToken() async =>
      tokens[_i < tokens.length ? _i : tokens.length - 1];

  @override
  Future<void> invalidate(String token) async {
    invalidated.add(token);
    _i++;
  }
}

Map<String, dynamic> _file(String id, String modified) => {
  'id': id,
  'name': 'redemption-backup-$id.zip',
  'size': '2048',
  'modifiedTime': modified,
  'appProperties': {'entries': '42', 'installId': 'abcd'},
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('list follows pages and only looks in the app folder', () async {
    final requests = <http.Request>[];
    final client = DriveClient(
      _Tokens(['t1']),
      httpClient: MockClient((req) async {
        requests.add(req);
        final page = req.url.queryParameters['pageToken'];
        return page == null
            ? _json({
                'files': [_file('a', '2026-10-10T08:00:00Z')],
                'nextPageToken': 'p2',
              })
            : _json({
                'files': [
                  _file('b', '2026-10-09T08:00:00Z'),
                  _file('c', '2026-10-08T08:00:00Z'),
                ],
              });
      }),
    );

    final files = await client.list();

    expect(files.map((f) => f.id), ['a', 'b', 'c']);
    expect(files.first.sizeBytes, 2048);
    expect(files.first.appProperties['entries'], '42');
    expect(files.first.modifiedTime, DateTime.utc(2026, 10, 10, 8).toLocal());
    expect(requests, hasLength(2));
    expect(requests.first.url.queryParameters['spaces'], 'appDataFolder');
    expect(requests.last.url.queryParameters['pageToken'], 'p2');
    expect(requests.first.headers['Authorization'], 'Bearer t1');
  });

  test('a new upload starts a resumable session in appDataFolder', () async {
    final requests = <http.Request>[];
    final client = DriveClient(
      _Tokens(['t1']),
      httpClient: MockClient((req) async {
        requests.add(req);
        if (req.method == 'POST') {
          return http.Response(
            '',
            200,
            headers: {'location': 'https://upload.test/session/1'},
          );
        }
        return _json(_file('new', '2026-10-10T08:00:00Z'));
      }),
    );

    final bytes = Uint8List.fromList(List.filled(10, 7));
    final file = await client.upload(
      name: 'redemption-backup-x.zip',
      bytes: bytes,
      appProperties: {'entries': '3'},
    );

    expect(file.id, 'new');
    final start = requests[0];
    expect(start.method, 'POST');
    expect(start.url.path, '/upload/drive/v3/files');
    expect(start.url.queryParameters['uploadType'], 'resumable');
    expect(start.headers['X-Upload-Content-Length'], '10');
    final metadata = jsonDecode(start.body) as Map<String, dynamic>;
    expect(metadata['parents'], ['appDataFolder']);
    expect(metadata['appProperties'], {'entries': '3'});
    final put = requests[1];
    expect(put.method, 'PUT');
    expect(put.url.toString(), 'https://upload.test/session/1');
    expect(put.bodyBytes, bytes);
  });

  test('updating an existing file patches it without re-parenting', () async {
    final requests = <http.Request>[];
    final client = DriveClient(
      _Tokens(['t1']),
      httpClient: MockClient((req) async {
        requests.add(req);
        if (req.method == 'PATCH') {
          return http.Response('', 200, headers: {'location': 'https://u/s'});
        }
        return _json(_file('old', '2026-10-10T08:00:00Z'));
      }),
    );

    await client.upload(name: 'n.zip', bytes: Uint8List(1), existingId: 'old');

    expect(requests[0].method, 'PATCH');
    expect(requests[0].url.path, '/upload/drive/v3/files/old');
    expect(
      (jsonDecode(requests[0].body) as Map).containsKey('parents'),
      isFalse,
    );
  });

  test('a rejected token is invalidated and the call retried once', () async {
    final tokens = _Tokens(['stale', 'fresh']);
    final seen = <String?>[];
    final client = DriveClient(
      tokens,
      httpClient: MockClient((req) async {
        seen.add(req.headers['Authorization']);
        return req.headers['Authorization'] == 'Bearer stale'
            ? _json({
                'error': {'message': 'Invalid Credentials'},
              }, 401)
            : _json({'files': <Object>[]});
      }),
    );

    expect(await client.list(), isEmpty);
    expect(tokens.invalidated, ['stale']);
    expect(seen, ['Bearer stale', 'Bearer fresh']);
  });

  test('a second 401 surfaces as unauthorized', () async {
    final client = DriveClient(
      _Tokens(['a', 'b']),
      httpClient: MockClient(
        (_) async => _json({
          'error': {'message': 'nope'},
        }, 401),
      ),
    );
    await expectLater(
      client.list(),
      throwsA(
        isA<DriveApiException>().having((e) => e.isUnauthorized, '401', true),
      ),
    );
  });

  test('API errors carry Google’s message', () async {
    final client = DriveClient(
      _Tokens(['t']),
      httpClient: MockClient(
        (_) async => _json({
          'error': {
            'message': 'The user has exceeded their Drive storage quota',
          },
        }, 403),
      ),
    );
    await expectLater(
      client.delete('x'),
      throwsA(
        isA<DriveApiException>()
            .having((e) => e.isForbidden, 'forbidden', true)
            .having((e) => e.message, 'message', contains('quota')),
      ),
    );
  });

  test('without a token nothing is sent', () async {
    var calls = 0;
    final client = DriveClient(
      _Tokens([null]),
      httpClient: MockClient((_) async {
        calls++;
        return _json({});
      }),
    );
    await expectLater(client.list(), throwsA(isA<DriveApiException>()));
    expect(calls, 0);
  });
}
