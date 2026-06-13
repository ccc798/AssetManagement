import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/category_dao.dart';
import '../../data/models/category.dart';

final categoryDaoProvider = Provider<CategoryDao>((ref) => CategoryDao());

/// 分类版本号 — CRUD 后 bump，categoryListProvider 自动刷新
final categoryVersionProvider = StateProvider<int>((ref) => 0);

/// 所有活跃分类（监听版本号实现自动刷新）
final categoryListProvider = FutureProvider<List<CategoryItem>>((ref) async {
  ref.watch(categoryVersionProvider);
  final dao = ref.read(categoryDaoProvider);
  return dao.getActive();
});

/// 所有分类包括已删除（监听版本号实现自动刷新）
final allCategoriesProvider = FutureProvider<List<CategoryItem>>((ref) async {
  ref.watch(categoryVersionProvider);
  final dao = ref.read(categoryDaoProvider);
  return dao.getAll(includeDeleted: true);
});
