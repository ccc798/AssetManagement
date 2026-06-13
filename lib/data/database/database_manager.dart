import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/asset_item.dart';
import 'package:collection/collection.dart';

/// 基于文件的 JSON 存储管理器
class DatabaseManager {
  DatabaseManager._();
  static final DatabaseManager instance = DatabaseManager._();

  List<AssetItem> _items = [];
  String? _dbPath;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    _dbPath = '${dir.path}/asset_management_data.json';
    await _load();
    _initialized = true;
  }

  Future<void> _load() async {
    if (_dbPath == null) return;
    final file = File(_dbPath!);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _items = jsonList.map((e) => AssetItem.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        _items = [];
      }
    } else {
      _items = [];
      await _save();
    }
  }

  Future<void> _save() async {
    if (_dbPath == null) return;
    try {
      final file = File(_dbPath!);
      final content = jsonEncode(_items.map((e) => e.toJson()).toList());
      await file.writeAsString(content);
    } catch (e) {
      // 写入失败时不崩溃，静默处理（下次操作会重试）
    }
  }

  /// 默认排序比较器（按购买日期降序）
  static int _defaultSort(AssetItem a, AssetItem b) {
    final aDate = a.purchaseDate ?? DateTime(2000);
    final bDate = b.purchaseDate ?? DateTime(2000);
    return bDate.compareTo(aDate);
  }

  /// 通用过滤方法
  /// [isDeleted]: null=不限制, true=仅删除, false=未删除
  /// [isArchived]: null=不限制, true=仅归档, false=未归档
  List<AssetItem> _filter({
    bool? isDeleted,
    bool? isArchived,
    bool sort = true,
  }) {
    _ensureInitialized();
    
    var result = _items.where((item) {
      if (isDeleted != null && item.isDeleted != isDeleted) return false;
      if (isArchived != null && item.isArchived != isArchived) return false;
      return true;
    }).toList();

    if (sort) {
      result.sort(_defaultSort);
    }
    
    return result;
  }

  /// 获取使用中的物品（未归档 + 未删除）
  List<AssetItem> getAll({bool includeDeleted = false}) {
    if (includeDeleted) {
      final list = List<AssetItem>.from(_items);
      list.sort(_defaultSort);
      return list;
    }
    return _filter(isDeleted: false, isArchived: false);
  }

  /// 分页获取物品（未归档 + 未删除）
  /// [page]: 页码，从 0 开始
  /// [pageSize]: 每页大小
  List<AssetItem> getPaged(int page, int pageSize, {bool includeDeleted = false}) {
    final allItems = getAll(includeDeleted: includeDeleted);
    final start = page * pageSize;
    if (start >= allItems.length) return [];
    final end = start + pageSize;
    return allItems.sublist(start, end > allItems.length ? allItems.length : end);
  }

  /// 获取物品总数（未归档 + 未删除）
  int getCount({bool includeDeleted = false}) {
    _ensureInitialized();
    if (includeDeleted) {
      return _items.length;
    }
    return _items.where((item) => !item.isDeleted && !item.isArchived).length;
  }

  /// 获取已归档的物品
  List<AssetItem> getArchived() {
    return _filter(isDeleted: false, isArchived: true);
  }

  /// 获取已软删除的物品
  List<AssetItem> getDeleted() {
    return _filter(isDeleted: true);
  }

  /// 按 ID 获取
  AssetItem? getById(int id) {
    _ensureInitialized();
    return _items.firstWhereOrNull((item) => item.id == id);
  }

  /// 搜索
  List<AssetItem> search(String keyword) {
    _ensureInitialized();
    final kw = keyword.toLowerCase();
    return _items.where((item) {
      if (item.isDeleted || item.isArchived) return false;
      return item.name.toLowerCase().contains(kw) ||
          item.brand.toLowerCase().contains(kw) ||
          item.category.toLowerCase().contains(kw) ||
          item.notes.toLowerCase().contains(kw);
    }).toList()..sort(_defaultSort);
  }

  /// 按分类获取（仅活跃物品）
  List<AssetItem> getByCategory(String category) {
    _ensureInitialized();
    return _items.where((item) =>
        item.category == category && !item.isDeleted && !item.isArchived).toList()..sort(_defaultSort);
  }

  /// 按分类获取全部物品（含已删除/已归档）
  List<AssetItem> getByCategoryAll(String category) {
    _ensureInitialized();
    return _items.where((item) => item.category == category).toList()..sort(_defaultSort);
  }

  /// 按分类硬删除所有物品
  Future<void> deleteByCategory(String category) async {
    _ensureInitialized();
    _items.removeWhere((item) => item.category == category);
    await _save();
  }

  /// 添加物品
  Future<AssetItem> add(AssetItem item) async {
    _ensureInitialized();
    final maxId = _items.isEmpty ? 0 : _items.map((e) => e.id).reduce((a, b) => a > b ? a : b);
    final newItem = item.copyWith(id: maxId + 1);
    _items.add(newItem);
    await _save();
    return newItem;
  }

  /// 更新物品
  Future<AssetItem> update(AssetItem item) async {
    _ensureInitialized();
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index >= 0) {
      final updated = item.copyWith(updatedAt: DateTime.now());
      _items[index] = updated;
      await _save();
      return updated;
    }
    return item;
  }

  /// 硬删除（从数据库中彻底移除）
  Future<void> hardDelete(int id) async {
    _ensureInitialized();
    _items.removeWhere((item) => item.id == id && item.isDeleted);
    await _save();
  }

  /// 软删除
  Future<void> softDelete(int id) async {
    _ensureInitialized();
    final index = _items.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(
        isDeleted: true,
        updatedAt: DateTime.now(),
      );
      await _save();
    }
  }

  /// 获取统计数据
  Map<String, dynamic> getStatistics({String scope = 'active', int months = 0}) {
    _ensureInitialized();
    
    final active = switch (scope) {
      'all' => _filter(isDeleted: false, sort: false),
      'archived' => getArchived(),
      _ => getAll(),
    };

    final filtered = months > 0 
        ? active.where((item) {
            if (item.purchaseDate == null) return false;
            final cutoff = DateTime.now().subtract(Duration(days: 30 * months));
            return item.purchaseDate!.isAfter(cutoff);
          }).toList()
        : active;

    if (filtered.isEmpty) {
      return _emptyStatistics();
    }

    return _calculateStatistics(filtered);
  }

  /// 空统计结果
  Map<String, dynamic> _emptyStatistics() {
    return {
      'totalCount': 0,
      'totalPrice': 0.0,
      'avgPrice': 0.0,
      'maxPrice': 0.0,
      'minPrice': 0.0,
      'categoryStats': <String, double>{},
      'monthlyStats': <String, double>{},
      'dailyAvgCost': 0.0,
    };
  }

  /// 计算统计数据
  Map<String, dynamic> _calculateStatistics(List<AssetItem> items) {
    final totalPrice = items.fold<double>(0, (sum, item) => sum + item.price);
    final prices = items.map((e) => e.price).toList()..sort();
    final totalDailyCost = items.fold<double>(0, (sum, item) => sum + item.dailyCost);

    final Map<String, double> categoryStats = {};
    final Map<String, double> monthlyStats = {};

    for (final item in items) {
      categoryStats.update(item.category, (v) => v + item.price, ifAbsent: () => item.price);
      
      if (item.purchaseDate != null) {
        final key = '${item.purchaseDate!.year}-${item.purchaseDate!.month.toString().padLeft(2, '0')}';
        monthlyStats.update(key, (v) => v + item.price, ifAbsent: () => item.price);
      }
    }

    return {
      'totalCount': items.length,
      'totalPrice': totalPrice,
      'avgPrice': totalPrice / items.length,
      'maxPrice': prices.isNotEmpty ? prices.last : 0.0,
      'minPrice': prices.isNotEmpty ? prices.first : 0.0,
      'categoryStats': categoryStats,
      'monthlyStats': monthlyStats,
      'dailyAvgCost': totalDailyCost,
    };
  }

  /// 用云端数据完全替换本地数据
  Future<void> replaceAll(List<AssetItem> remote) async {
    _ensureInitialized();
    _items = List.from(remote);
    await _save();
  }

  /// 合并云端与本地数据（按 uuid 去重）
  Future<void> mergeDeduplicated(List<AssetItem> remote) async {
    _ensureInitialized();
    final localUuids = _items.map((e) => e.uuid).toSet();
    
    // 添加云端有但本地没有的
    final toAdd = remote.where((r) => !localUuids.contains(r.uuid)).toList();
    
    // 合并：用云端数据替换本地相同 uuid 的数据
    final merged = _items.map((local) {
      return remote.firstWhereOrNull((r) => r.uuid == local.uuid) ?? local;
    }).toList()..addAll(toAdd);
    
    _items = merged;
    await _save();
  }

  Future<String> get dbPath async {
    if (_dbPath != null) return _dbPath!;
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/asset_management_data.json';
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('Database not initialized. Call init() first.');
    }
  }

  bool get isInitialized => _initialized;
}