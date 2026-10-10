import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Local-first observability: structured logs kept in a ring buffer (for the
/// in-app Diagnostics screen) and appended to a size-capped rotating file.
/// Nothing ever leaves the device unless the user explicitly shares it.
class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  static const _bufferSize = 600;
  static const _maxFileBytes = 512 * 1024;

  final _buffer = ListQueue<LogRecord>(_bufferSize);
  final _changes = StreamController<void>.broadcast();
  File? _file;
  IOSink? _sink;
  StreamSubscription<LogRecord>? _subscription;

  List<LogRecord> get records => List.unmodifiable(_buffer);

  Stream<void> get changes => _changes.stream;

  File? get logFile => _file;

  /// Hooks `package:logging` up. Safe to call more than once.
  Future<void> init({bool withFile = true}) async {
    Logger.root.level = kReleaseMode ? Level.INFO : Level.ALL;
    await _subscription?.cancel();
    _subscription = Logger.root.onRecord.listen(_onRecord);
    if (withFile) {
      try {
        final dir = await getApplicationSupportDirectory();
        final logDir = Directory(p.join(dir.path, 'logs'));
        await logDir.create(recursive: true);
        _file = File(p.join(logDir.path, 'app.log'));
        await _rotateIfNeeded();
        _sink = _file!.openWrite(mode: FileMode.append);
      } catch (e) {
        debugPrint('AppLogger: file logging disabled ($e)');
      }
    }
  }

  void _onRecord(LogRecord r) {
    if (_buffer.length == _bufferSize) _buffer.removeFirst();
    _buffer.addLast(r);
    final line = format(r);
    if (kDebugMode) debugPrint(line);
    _sink?.writeln(line);
    _changes.add(null);
  }

  Future<void> _rotateIfNeeded() async {
    final f = _file;
    if (f == null || !f.existsSync()) return;
    if (await f.length() < _maxFileBytes) return;
    final old = File('${f.path}.1');
    if (old.existsSync()) await old.delete();
    await f.rename(old.path);
  }

  static String format(LogRecord r) {
    final buf = StringBuffer()
      ..write(r.time.toIso8601String())
      ..write(' ')
      ..write(r.level.name.padRight(7))
      ..write(' [')
      ..write(r.loggerName)
      ..write('] ')
      ..write(r.message);
    if (r.error != null) buf.write(' | error: ${r.error}');
    if (r.stackTrace != null) buf.write('\n${r.stackTrace}');
    return buf.toString();
  }

  String dump() => _buffer.map(format).join('\n');

  Future<void> clear() async {
    _buffer.clear();
    await _sink?.flush();
    await _sink?.close();
    if (_file != null && _file!.existsSync()) await _file!.writeAsString('');
    if (_file != null) _sink = _file!.openWrite(mode: FileMode.append);
    _changes.add(null);
  }

  Future<void> flush() async => _sink?.flush();
}
