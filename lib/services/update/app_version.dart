import 'package:flutter/foundation.dart';

/// A semantic version such as `1.2.3` or `1.3.0-beta.1` (build metadata
/// after `+` is ignored, a leading `v` is accepted).
@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, {this.preRelease = ''});

  static final _pattern = RegExp(
    r'^v?(\d+)\.(\d+)(?:\.(\d+))?(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]*)?$',
  );

  static AppVersion? tryParse(String text) {
    final m = _pattern.firstMatch(text.trim());
    if (m == null) return null;
    return AppVersion(
      int.parse(m[1]!),
      int.parse(m[2]!),
      int.parse(m[3] ?? '0'),
      preRelease: m[4] ?? '',
    );
  }

  final int major;
  final int minor;
  final int patch;

  /// Empty for a final release; a final release sorts after its pre-releases.
  final String preRelease;

  @override
  int compareTo(AppVersion other) {
    for (final (a, b) in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      if (a != b) return a.compareTo(b);
    }
    if (preRelease == other.preRelease) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;
    return _comparePre(preRelease, other.preRelease);
  }

  /// SemVer §11: dot-separated identifiers, numeric ones compared as numbers.
  static int _comparePre(String a, String b) {
    final x = a.split('.');
    final y = b.split('.');
    for (var i = 0; i < x.length && i < y.length; i++) {
      final nx = int.tryParse(x[i]);
      final ny = int.tryParse(y[i]);
      final c = switch ((nx, ny)) {
        (final p?, final q?) => p.compareTo(q),
        (_?, null) => -1,
        (null, _?) => 1,
        _ => x[i].compareTo(y[i]),
      };
      if (c != 0) return c;
    }
    return x.length.compareTo(y.length);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator <(AppVersion other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease);

  @override
  String toString() =>
      '$major.$minor.$patch${preRelease.isEmpty ? '' : '-$preRelease'}';
}
