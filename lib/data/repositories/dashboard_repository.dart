import 'package:drift/drift.dart';

import '../../domain/dashboard.dart';
import '../db/database.dart';
import 'mappers.dart';

class DashboardRepository {
  DashboardRepository(this._db);

  final AppDatabase _db;

  Stream<List<DashboardItem>> watch(int journeyId) {
    final q = _db.select(_db.dashboardItems)
      ..where((d) => d.journeyId.equals(journeyId))
      ..orderBy([
        (d) => OrderingTerm.asc(d.sortOrder),
        (d) => OrderingTerm.asc(d.id),
      ]);
    return q.watch().map((rows) => [for (final r in rows) ?r.toDomain()]);
  }

  Future<int> add(DashboardItem item) async {
    final maxOrder = _db.dashboardItems.sortOrder.max();
    final q = _db.selectOnly(_db.dashboardItems)
      ..addColumns([maxOrder])
      ..where(_db.dashboardItems.journeyId.equals(item.journeyId));
    final next = ((await q.getSingle()).read(maxOrder) ?? -1) + 1;
    return _db
        .into(_db.dashboardItems)
        .insert(
          DashboardItemsCompanion.insert(
            journeyId: item.journeyId,
            kind: item.kind.name,
            size: Value(item.size.name),
            config: Value(item.config),
            sortOrder: Value(next),
          ),
        );
  }

  Future<void> update(DashboardItem item) =>
      (_db.update(
        _db.dashboardItems,
      )..where((d) => d.id.equals(item.id))).write(
        DashboardItemsCompanion(
          size: Value(item.size.name),
          config: Value(item.config),
        ),
      );

  Future<void> remove(int id) =>
      (_db.delete(_db.dashboardItems)..where((d) => d.id.equals(id))).go();

  Future<void> reorder(List<int> orderedIds) => _db.batch((b) {
    for (final (i, id) in orderedIds.indexed) {
      b.update(
        _db.dashboardItems,
        DashboardItemsCompanion(sortOrder: Value(i)),
        where: (d) => d.id.equals(id),
      );
    }
  });
}
