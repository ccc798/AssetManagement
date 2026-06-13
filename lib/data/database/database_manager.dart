import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/asset_item.dart';
import 'package:collection/collection.dart';

/// 基于文件的 JSON 存储管理器
///
/// 不使用代码生成，纯 Dart 实现，跨平台兼容
class DatabaseManager {
  DatabaseManager._();
  static final DatabaseManager instance = DatabaseManager._();

  List<AssetItem> _items = [];
  String? _dbPath;
  bool _initialized = false;

  /// 初始化数据库
  Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    _dbPath = '${dir.path}/asset_management_data.json';
    await _load();
    _initialized = true;
  }

  /// 从文件加载数据
  Future<void> _load() async {
    if (_dbPath == null) return;
    final file = File(_dbPath!);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _items = jsonList
            .map((e) => AssetItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        _items = [];
      }
    } else {
      // 首次运行，初始化预设数据
      _items = [];
      await _save();
    }
  }

  /// 保存到文件
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

  /// 获取使用中的物品（未归档 + 未删除）
  List<AssetItem> getAll({bool includeDeleted = false}) {
    _ensureInitialized();
    if (includeDeleted) {
      return List.from(_items);
    }
    return _items.where((item) => !item.isDeleted && !item.isArchived).toList()
      ..sort((a, b) {
        final aDate = a.purchaseDate ?? DateTime(2000);
        final bDate = b.purchaseDate ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
  }

  /// 获取已归档的物品
  List<AssetItem> getArchived() {
    _ensureInitialized();
    return _items.where((item) => item.isArchived && !item.isDeleted).toList()
      ..sort((a, b) {
        final aDate = a.purchaseDate ?? DateTime(2000);
        final bDate = b.purchaseDate ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
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
    }).toList();
  }

  /// 按分类获取（仅活跃物品）
  List<AssetItem> getByCategory(String category) {
    _ensureInitialized();
    return _items.where((item) =>
        item.category == category && !item.isDeleted && !item.isArchived).toList();
  }

  /// 按分类获取全部物品（含已删除/已归档，用于统计和删除确认）
  List<AssetItem> getByCategoryAll(String category) {
    _ensureInitialized();
    return _items.where((item) => item.category == category).toList();
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

  /// 获取已软删除的物品
  List<AssetItem> getDeleted() {
    _ensureInitialized();
    return _items.where((item) => item.isDeleted).toList()
      ..sort((a, b) {
        final aDate = a.purchaseDate ?? DateTime(2000);
        final bDate = b.purchaseDate ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
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
  /// [scope] 'all'=全部 'active'=使用中 'archived'=已归档
  /// [months] 时间范围月数，0=全部
  Map<String, dynamic> getStatistics({String scope = 'active', int months = 0}) {
    _ensureInitialized();
    var active = scope == 'all'
        ? _items.where((item) => !item.isDeleted).toList()
        : scope == 'archived'
            ? getArchived()
            : getAll();

    // 时间过滤
    if (months > 0) {
      final cutoff = DateTime.now().subtract(Duration(days: 30 * months));
      active = active.where((item) {
        if (item.purchaseDate == null) return false;
        return item.purchaseDate!.isAfter(cutoff);
      }).toList();
    }

    if (active.isEmpty) {
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

    final totalPrice = active.fold<double>(0, (sum, item) => sum + item.price);
    final prices = active.map((e) => e.price).toList()..sort();
    final totalDailyCost = active.fold<double>(0, (sum, item) => sum + item.dailyCost);

    final Map<String, double> categoryStats = {};
    for (final item in active) {
      categoryStats.update(
        item.category,
        (v) => v + item.price,
        ifAbsent: () => item.price,
      );
    }

    final Map<String, double> monthlyStats = {};
    for (final item in active) {
      if (item.purchaseDate == null) continue;
      final key = '${item.purchaseDate!.year}-${item.purchaseDate!.month.toString().padLeft(2, '0')}';
      monthlyStats.update(
        key,
        (v) => v + item.price,
        ifAbsent: () => item.price,
      );
    }

    return {
      'totalCount': active.length,
      'totalPrice': totalPrice,
      'avgPrice': totalPrice / active.length,
      'maxPrice': prices.isNotEmpty ? prices.last : 0.0,
      'minPrice': prices.isNotEmpty ? prices.first : 0.0,
      'categoryStats': categoryStats,
      'monthlyStats': monthlyStats,
      'dailyAvgCost': totalDailyCost,
    };
  }

  /// 用云端数据完全替换本地数据（覆盖模式）
  Future<void> replaceAll(List<AssetItem> remote) async {
    _ensureInitialized();
    _items = List.from(remote);
    await _save();
  }

  /// 合并云端与本地数据（按 uuid 去重，相同 uuid 以云端为准）
  Future<void> mergeDeduplicated(List<AssetItem> remote) async {
    _ensureInitialized();
    final localUuids = _items.map((e) => e.uuid).toSet();
    final remoteUuids = remote.map((e) => e.uuid).toSet();

    // 1. 云端有、本地没有 → 添加
    final toAdd = remote.where((r) => !localUuids.contains(r.uuid)).toList();

    // 2. 云端和本地都有 → 用云端的替换本地
    final merged = _items.map((local) {
      final match = remote.where((r) => r.uuid == local.uuid).firstOrNull;
      return match ?? local;
    }).toList();

    // 3. 本地有、云端没有 → 保留（已在 merged 中）
    merged.addAll(toAdd);
    _items = merged;
    await _save();
  }

  /// 获取数据库文件路径（用于备份）
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
