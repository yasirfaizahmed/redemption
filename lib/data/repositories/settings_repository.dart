import '../../domain/app_settings.dart';
import '../db/database.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Stream<AppSettings> watch() => _db
      .select(_db.settings)
      .watch()
      .map(
        (rows) => AppSettings.fromMap({for (final r in rows) r.key: r.value}),
      );

  Future<AppSettings> load() async {
    final rows = await _db.select(_db.settings).get();
    return AppSettings.fromMap({for (final r in rows) r.key: r.value});
  }

  Future<void> save(AppSettings settings) => _db.batch((b) {
    b.insertAllOnConflictUpdate(_db.settings, [
      for (final e in settings.toMap().entries)
        SettingsCompanion.insert(key: e.key, value: e.value),
    ]);
  });
}
