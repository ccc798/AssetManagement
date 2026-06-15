import '../models/related_pool.dart';
import 'database_manager.dart';

class RelatedPoolDao {
  static final RelatedPoolDao instance = RelatedPoolDao._();
  RelatedPoolDao._();

  final DatabaseManager _db = DatabaseManager.instance;

  Future<List<RelatedPool>> getAll() async {
    await _db.init();
    return _db.getRelatedPools();
  }

  Future<RelatedPool?> getByUuid(String uuid) async {
    await _db.init();
    return _db.getRelatedPoolByUuid(uuid);
  }

  Future<List<RelatedPool>> getByItemUuid(String itemUuid) async {
    await _db.init();
    return _db.getRelatedPoolsByItemUuid(itemUuid);
  }

  Future<RelatedPool> create(String name, String ownerItemUuid) async {
    await _db.init();
    final pool = RelatedPool(
      name: name,
      itemUuids: [ownerItemUuid],
    );
    await _db.addRelatedPool(pool);
    return pool;
  }

  Future<void> addItem(String poolUuid, String itemUuid) async {
    await _db.init();
    await _db.addItemToRelatedPool(poolUuid, itemUuid);
  }

  Future<void> removeItem(String poolUuid, String itemUuid) async {
    await _db.init();
    await _db.removeItemFromRelatedPool(poolUuid, itemUuid);
  }

  Future<void> update(RelatedPool pool) async {
    await _db.init();
    await _db.updateRelatedPool(pool);
  }

  Future<void> delete(String uuid) async {
    await _db.init();
    await _db.deleteRelatedPool(uuid);
  }
}