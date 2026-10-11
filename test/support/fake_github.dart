import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Serves a fake "latest release" with per-ABI APKs and SHA256SUMS.txt.
class FakeGitHub {
  FakeGitHub({
    this.tag = 'v9.9.0',
    List<int>? apkBytes,
    this.corruptChecksums = false,
    this.notes = "## What's new in v9.9.0\n\n- **Faster** dashboard\n  with *wrapped* lines\n- [Linked](https://x.y) fix\n\n## Install on Android\n\n1. Download",
  }) : apkBytes = apkBytes ?? List.generate(4096, (i) => i % 251);

  final String tag;
  final List<int> apkBytes;
  final bool corruptChecksums;
  final String notes;

  /// Requests served, by path.
  final requests = <String>[];
  int status = 200;

  String get label => tag;
  String apkName(String abi) => 'redemption-$label-$abi.apk';

  Map<String, dynamic> get releaseJson => {
    'tag_name': tag,
    'name': 'Redemption $tag',
    'body': notes,
    'html_url': 'https://github.com/o/r/releases/tag/$tag',
    'published_at': '2026-10-11T10:00:00Z',
    'assets': [
      for (final abi in ['universal', 'arm64-v8a', 'armeabi-v7a'])
        {
          'name': apkName(abi),
          'browser_download_url': 'https://dl.test/${apkName(abi)}',
          'size': apkBytes.length,
        },
      {
        'name': 'SHA256SUMS.txt',
        'browser_download_url': 'https://dl.test/SHA256SUMS.txt',
        'size': 300,
      },
    ],
  };

  String get checksums {
    final hash = corruptChecksums
        ? '0' * 64
        : sha256.convert(apkBytes).toString();
    return [
      for (final abi in ['universal', 'arm64-v8a', 'armeabi-v7a'])
        '$hash  ${apkName(abi)}',
    ].join('\n');
  }

  late final http.Client client = MockClient((req) async {
    requests.add(req.url.path);
    if (status != 200) return http.Response('{}', status);
    if (req.url.host == 'api.github.com') {
      return http.Response(
        jsonEncode(releaseJson),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (req.url.path.endsWith('SHA256SUMS.txt')) {
      return http.Response(checksums, 200);
    }
    if (req.url.path.endsWith('.apk')) {
      return http.Response.bytes(apkBytes, 200);
    }
    return http.Response('not found', 404);
  });
}
