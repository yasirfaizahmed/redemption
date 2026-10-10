import 'dart:io';
import 'dart:math';

import 'package:cross_file/cross_file.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/tracker_value.dart';

final _log = Logger('AttachmentStore');

/// Owns the app-private directory where photos and files are copied.
/// Entries reference attachments by a path relative to [root].
class AttachmentStore {
  AttachmentStore(this.root);

  final Directory root;

  static Future<AttachmentStore> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'attachments'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return AttachmentStore(dir);
  }

  final _random = Random();

  File resolve(Attachment a) => File(p.join(root.path, a.relativePath));

  /// Copies a picked file (camera, gallery or document picker) into the store
  /// and returns its attachment record. Streams the bytes, so large files are
  /// never fully loaded in memory.
  Future<Attachment> import(XFile source, {String? displayName}) async {
    final name = displayName ?? source.name;
    final ext = p.extension(name).toLowerCase();
    final now = DateTime.now();
    final folder = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final unique =
        '${now.millisecondsSinceEpoch}_${_random.nextInt(1 << 32).toRadixString(36)}$ext';
    final relative = p.join(folder, unique);
    final target = File(p.join(root.path, relative));
    await target.parent.create(recursive: true);
    final sink = target.openWrite();
    try {
      await sink.addStream(source.openRead());
    } finally {
      await sink.close();
    }
    final size = await target.length();
    _log.fine('Imported attachment $relative ($size bytes)');
    return Attachment(relativePath: relative, name: name, sizeBytes: size);
  }

  Future<void> writeBytes(String relativePath, List<int> bytes) async {
    final target = File(p.join(root.path, relativePath));
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
  }

  Stream<(String, File)> listAll() async* {
    if (!root.existsSync()) return;
    await for (final e in root.list(recursive: true)) {
      if (e is File) yield (p.relative(e.path, from: root.path), e);
    }
  }

  Future<int> totalSize() async {
    var total = 0;
    await for (final (_, f) in listAll()) {
      total += await f.length();
    }
    return total;
  }

  /// Deletes files no entry references any more. Files younger than
  /// [minAge] are kept: they may belong to an entry sheet still being edited.
  Future<int> deleteOrphans(
    Set<String> referenced, {
    Duration minAge = const Duration(hours: 24),
  }) async {
    var removed = 0;
    final cutoff = DateTime.now().subtract(minAge);
    await for (final (rel, f) in listAll()) {
      if (referenced.contains(rel)) continue;
      if ((await f.lastModified()).isAfter(cutoff)) continue;
      await f.delete();
      removed++;
    }
    if (removed > 0) _log.info('Removed $removed orphaned attachments');
    return removed;
  }

  Future<void> clear() async {
    if (root.existsSync()) await root.delete(recursive: true);
    await root.create(recursive: true);
  }
}
