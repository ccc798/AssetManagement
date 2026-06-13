import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../models/category.dart';

/// 分类数据访问 — 状态化单例
///
/// 数据持久化到 {docDir}/asset_management_categories.json
/// 首次启动自动写入预设分类（来自 AppConstants.presetCategories）
class CategoryDao {
  // ── 单例 ──
  static final CategoryDao _instance = CategoryDao._internal();
  factory CategoryDao() => _instance;
  CategoryDao._internal();

  List<CategoryItem>? _categories;
  String? _filePath;
  bool _loaded = false;

  Future<String> get _path async {
    if (_filePath != null) return _filePath!;
    final dir = await getApplicationDocumentsDirectory();
    _filePath = '${dir.path}/asset_management_categories.json';
    return _filePath!;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final file = File(await _path);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final list = jsonDecode(content) as List<dynamic>;
        _categories =
            list.map((e) => CategoryItem.fromJson(e as Map<String, dynamic>)).toList();
        _loaded = true;
        return;
      } catch (_) {
        // 文件损坏，回退到预设
      }
    }
    // 首次启动：写入预设分类
    _categories = AppConstants.presetCategories.asMap().entries.map((entry) {
      final i = entry.key;
      final data = entry.value;
      return CategoryItem(
        id: i + 1,
        name: data['name']!,
        icon: data['icon']!,
        colorHex: data['color']!,
        sortOrder: i,
        isPreset: true,
      );
    }).toList();
    await _save();
    _loaded = true;
  }

  Future<void> _save() async {
    if (_categories == null) return;
    final file = File(await _path);
    await file.writeAsString(
      jsonEncode(_categories!.map((c) => c.toJson()).toList()),
    );
  }

  /// 获取所有活跃分类（未删除）
  Future<List<CategoryItem>> getActive() async {
    await _ensureLoaded();
    return _categories!.where((c) => !c.isDeleted).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// 获取所有分类（含已删除）
  Future<List<CategoryItem>> getAll({bool includeDeleted = false}) async {
    await _ensureLoaded();
    if (includeDeleted) return List.from(_categories!);
    return _categories!.where((c) => !c.isDeleted).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// 按名称查找
  Future<CategoryItem?> getByName(String name) async {
    await _ensureLoaded();
    try {
      return _categories!.firstWhere((c) => c.name == name && !c.isDeleted);
    } catch (_) {
      return null;
    }
  }

  /// 添加分类
  Future<CategoryItem> add(String name, String icon, String colorHex) async {
    await _ensureLoaded();
    final maxId = _categories!.isEmpty
        ? 0
        : _categories!.map((c) => c.id).reduce((a, b) => a > b ? a : b);
    final maxOrder = _categories!.isEmpty
        ? 0
        : _categories!.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b);
    final cat = CategoryItem(
      id: maxId + 1,
      name: name,
      icon: icon,
      colorHex: colorHex,
      sortOrder: maxOrder + 1,
    );
    _categories!.add(cat);
    await _save();
    return cat;
  }

  /// 更新分类
  Future<CategoryItem> update(int id,
      {String? name, String? icon, String? colorHex}) async {
    await _ensureLoaded();
    final idx = _categories!.indexWhere((c) => c.id == id);
    if (idx < 0) throw Exception('分类不存在');
    _categories![idx] = _categories![idx].copyWith(
      name: name,
      icon: icon,
      colorHex: colorHex,
    );
    await _save();
    return _categories![idx];
  }

  /// 彻底删除分类
  Future<void> delete(int id) async {
    await _ensureLoaded();
    final idx = _categories!.indexWhere((c) => c.id == id);
    if (idx < 0) throw Exception('分类不存在');
    _categories!.removeAt(idx);
    await _save();
  }
}
