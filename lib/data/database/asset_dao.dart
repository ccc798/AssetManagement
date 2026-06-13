import '../models/asset_item.dart';
import 'database_manager.dart';

/// 资产物品数据访问
class AssetDao {
  final DatabaseManager _db = DatabaseManager.instance;

  Future<List<AssetItem>> getAll({bool includeDeleted = false}) async {
    await _db.init();
    return _db.getAll(includeDeleted: includeDeleted);
  }

  Future<AssetItem?> getById(int id) async {
    await _db.init();
    return _db.getById(id);
  }

  Future<List<AssetItem>> search(String keyword) async {
    await _db.init();
    return _db.search(keyword);
  }

  Future<List<AssetItem>> getByCategory(String category) async {
    await _db.init();
    return _db.getByCategory(category);
  }

  Future<List<AssetItem>> getByCategoryAll(String category) async {
    await _db.init();
    return _db.getByCategoryAll(category);
  }

  Future<void> deleteByCategory(String category) async {
    await _db.init();
    return _db.deleteByCategory(category);
  }

  Future<AssetItem> add(AssetItem item) async {
    await _db.init();
    return _db.add(item);
  }

  Future<AssetItem> update(AssetItem item) async {
    await _db.init();
    return _db.update(item);
  }

  Future<void> softDelete(int id) async {
    await _db.init();
    return _db.softDelete(id);
  }

  Future<void> hardDelete(int id) async {
    await _db.init();
    return _db.hardDelete(id);
  }

  Future<List<AssetItem>> getDeleted() async {
    await _db.init();
    return _db.getDeleted();
  }

  Future<Map<String, dynamic>> getStatistics({String scope = 'active', int months = 0}) async {
    await _db.init();
    return _db.getStatistics(scope: scope, months: months);
  }

  Future<List<AssetItem>> getArchived() async {
    await _db.init();
    return _db.getArchived();
  }
}
