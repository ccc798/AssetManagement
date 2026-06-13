import '../database/asset_dao.dart';
import '../models/asset_item.dart';

class AssetRepository {
  final AssetDao _assetDao;

  AssetRepository({
    AssetDao? assetDao,
  })  : _assetDao = assetDao ?? AssetDao();

  Future<List<AssetItem>> getItems({
    String? category,
    String? searchQuery,
    bool includeArchived = false,
    bool includeDeleted = false,
    int page = 0,
    int pageSize = 20,
  }) async {
    List<AssetItem> items;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      items = await _assetDao.search(searchQuery);
    } else if (category != null && category.isNotEmpty) {
      items = includeDeleted
          ? await _assetDao.getByCategoryAll(category)
          : await _assetDao.getByCategory(category);
    } else {
      items = includeArchived
          ? await _assetDao.getArchived()
          : await _assetDao.getAll(includeDeleted: includeDeleted);
    }

    if (pageSize > 0) {
      final start = page * pageSize;
      if (start >= items.length) return [];
      final end = start + pageSize;
      return items.sublist(start, end > items.length ? items.length : end);
    }

    return items;
  }

  Future<int> getItemCount({
    String? category,
    String? searchQuery,
    bool includeArchived = false,
    bool includeDeleted = false,
  }) async {
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final items = await _assetDao.search(searchQuery);
      return items.length;
    }
    return _assetDao.getCount(includeDeleted: includeDeleted);
  }

  Future<AssetItem?> getItemById(int id) async {
    return _assetDao.getById(id);
  }

  Future<AssetItem> createItem(AssetItem item) async {
    return _assetDao.add(item);
  }

  Future<AssetItem> updateItem(AssetItem item) async {
    return _assetDao.update(item);
  }

  Future<void> softDeleteItem(int id) async {
    await _assetDao.softDelete(id);
  }

  Future<void> hardDeleteItem(int id) async {
    await _assetDao.hardDelete(id);
  }

  Future<void> restoreItem(int id) async {
    final item = await _assetDao.getById(id);
    if (item != null && item.isDeleted) {
      await _assetDao.update(item.copyWith(isDeleted: false));
    }
  }

  Future<void> archiveItem(int id, {bool archived = true}) async {
    final item = await _assetDao.getById(id);
    if (item != null) {
      await _assetDao.update(item.copyWith(isArchived: archived));
    }
  }

  Future<Map<String, dynamic>> getStatistics({
    String scope = 'active',
    int months = 0,
  }) async {
    return _assetDao.getStatistics(scope: scope, months: months);
  }

  Future<void> deleteByCategory(String category) async {
    await _assetDao.deleteByCategory(category);
  }
}