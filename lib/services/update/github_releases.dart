import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'app_version.dart';

final _log = Logger('Updates');

class UpdateException implements Exception {
  UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.url,
    required this.sizeBytes,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) => ReleaseAsset(
    name: json['name'] as String? ?? '',
    url: json['browser_download_url'] as String? ?? '',
    sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
  );

  final String name;
  final String url;
  final int sizeBytes;
}

/// A published GitHub release of the app.
class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.version,
    required this.name,
    required this.notes,
    required this.htmlUrl,
    required this.assets,
    this.publishedAt,
  });

  /// Null when the tag is not a version (such releases are ignored).
  static ReleaseInfo? fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String? ?? '';
    final version = AppVersion.tryParse(tag);
    if (version == null) return null;
    return ReleaseInfo(
      tag: tag,
      version: version,
      name: json['name'] as String? ?? tag,
      notes: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '')
          ?.toLocal(),
      assets: [
        for (final a in json['assets'] as List<dynamic>? ?? const [])
          ReleaseAsset.fromJson(a as Map<String, dynamic>),
      ],
    );
  }

  final String tag;
  final AppVersion version;
  final String name;

  /// Release body (Markdown).
  final String notes;
  final String htmlUrl;
  final DateTime? publishedAt;
  final List<ReleaseAsset> assets;

  static const checksumsName = 'SHA256SUMS.txt';

  /// The APK for [abi] (e.g. `arm64-v8a`), else the universal one.
  ReleaseAsset? apkFor(String abi) {
    final apks = assets.where((a) => a.name.toLowerCase().endsWith('.apk'));
    return apks.where((a) => a.name.endsWith('-$abi.apk')).firstOrNull ??
        apks.where((a) => a.name.endsWith('-universal.apk')).firstOrNull ??
        apks.firstOrNull;
  }

  ReleaseAsset? get checksums =>
      assets.where((a) => a.name == checksumsName).firstOrNull;

  /// The "What's new" part of the release body as plain text: the section
  /// under a `What's new` heading, else the text before the first heading.
  /// Hard-wrapped Markdown lines are joined; list items become "• ".
  String get whatsNew {
    final lines = const LineSplitter().convert(notes);
    final heading = RegExp(r'^#{1,6}\s');
    final start = lines.indexWhere(
      (l) => RegExp(
        r'^#{1,6}\s+what.?s new',
        caseSensitive: false,
      ).hasMatch(l.trim()),
    );
    final bullet = RegExp(r'^[-*+]\s+');
    final out = <String>[];
    for (final raw in lines.skip(start + 1)) {
      if (heading.hasMatch(raw.trim())) break;
      final line = raw.trim();
      final item = bullet.firstMatch(line);
      if (line.isEmpty) {
        if (out.isNotEmpty && out.last.isNotEmpty) out.add('');
      } else if (item != null) {
        out.add('• ${line.substring(item.end)}');
      } else if (out.isNotEmpty && out.last.isNotEmpty) {
        out[out.length - 1] = '${out.last} $line';
      } else {
        out.add(line);
      }
    }
    return out
        .join('\n')
        .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!)
        .replaceAll(RegExp(r'\*\*|__|`|\*'), '')
        .trim();
  }
}

/// Reads the app's releases from the public GitHub API (no token: 60
/// requests per hour per IP, far more than a few checks a day need).
class GitHubReleases {
  GitHubReleases({this.repo = defaultRepo, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  static const defaultRepo = 'yasirfaizahmed/redemption';

  final String repo;
  final http.Client _http;

  static const _headers = {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'Redemption-app',
  };

  /// The newest published (non-draft, non-pre-release) release, or null
  /// when there is none.
  Future<ReleaseInfo?> latest() async {
    final http.Response res;
    try {
      res = await _http
          .get(
            Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 20));
    } on Exception catch (e) {
      _log.info('Update check failed: $e');
      throw UpdateException('Couldn’t reach GitHub. Check your connection.');
    }
    if (res.statusCode == 404) return null;
    if (res.statusCode == 403 || res.statusCode == 429) {
      throw UpdateException(
        'GitHub is rate-limiting update checks. Try again later.',
      );
    }
    if (res.statusCode != 200) {
      throw UpdateException('GitHub answered ${res.statusCode}.');
    }
    return ReleaseInfo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// SHA-256 of [asset] as published in the release's `SHA256SUMS.txt`, or
  /// null if the release has no checksum file.
  Future<String?> sha256For(ReleaseInfo release, ReleaseAsset asset) async {
    final sums = release.checksums;
    if (sums == null) return null;
    final res = await _http
        .get(
          Uri.parse(sums.url),
          headers: {'User-Agent': _headers['User-Agent']!},
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw UpdateException('Couldn’t download the checksums.');
    }
    for (final line in const LineSplitter().convert(res.body)) {
      final m = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+)$')
          .firstMatch(line.trim());
      if (m != null && m[2]!.trim() == asset.name) return m[1]!.toLowerCase();
    }
    throw UpdateException('${asset.name} is missing from the checksums.');
  }

  /// Streams [asset] to [target], verifying its size and (when given) its
  /// SHA-256. Nothing is left at [target] unless the file is complete and
  /// intact.
  Future<File> download(
    ReleaseAsset asset,
    File target, {
    String? sha256Hex,
    void Function(int received, int total)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(asset.url))
      ..headers['User-Agent'] = _headers['User-Agent']!
      ..headers['Accept'] = 'application/octet-stream';
    final res = await _http.send(request);
    if (res.statusCode != 200) {
      throw UpdateException('Download failed (HTTP ${res.statusCode}).');
    }
    final total = asset.sizeBytes > 0
        ? asset.sizeBytes
        : res.contentLength ?? 0;
    await target.parent.create(recursive: true);
    final part = File('${target.path}.part');
    final sink = part.openWrite();
    final digest = _DigestCapture();
    final hasher = sha256.startChunkedConversion(digest);
    var received = 0;
    try {
      await for (final chunk in res.stream.timeout(
        const Duration(seconds: 60),
      )) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
    } catch (e) {
      await _discard(sink, part);
      if (e is UpdateException) rethrow;
      throw UpdateException('Download interrupted. Try again.');
    }
    await sink.close();
    hasher.close();
    if (asset.sizeBytes > 0 && received != asset.sizeBytes) {
      await part.delete();
      throw UpdateException('Download incomplete. Try again.');
    }
    if (sha256Hex != null && digest.value.toString() != sha256Hex) {
      await part.delete();
      throw UpdateException(
        'The download is damaged (checksum mismatch) and was discarded.',
      );
    }
    if (target.existsSync()) await target.delete();
    final file = await part.rename(target.path);
    _log.info('Downloaded ${asset.name} ($received bytes, verified)');
    return file;
  }

  static Future<void> _discard(IOSink sink, File part) async {
    try {
      await sink.close();
    } catch (_) {}
    try {
      if (part.existsSync()) await part.delete();
    } catch (_) {}
  }

  void close() => _http.close();
}

class _DigestCapture implements Sink<Digest> {
  Digest? _value;
  Digest get value => _value!;
  @override
  void add(Digest data) => _value = data;
  @override
  void close() {}
}
