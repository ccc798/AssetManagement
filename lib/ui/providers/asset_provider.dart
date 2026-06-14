import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/asset_dao.dart';
import '../../data/models/asset_item.dart';

/// DAO 实例 provider
final assetDaoProvider = Provider<AssetDao>((ref) => AssetDao());

/// 数据版本号 — 所有写操作后 bump 一次，依赖它的 provider 自动刷新
final assetVersionProvider = StateProvider<int>((ref) => 0);

/// 已归档物品列表
final archivedListProvider = FutureProvider<List<AssetItem>>((ref) async {
  ref.watch(assetVersionProvider);
  final dao = ref.read(assetDaoProvider);
  return dao.getArchived();
});

/// 已删除物品列表
final deletedListProvider = FutureProvider<List<AssetItem>>((ref) async {
  ref.watch(assetVersionProvider);
  final dao = ref.read(assetDaoProvider);
  return dao.getDeleted();
});

/// 收藏物品列表
final favoriteListProvider = FutureProvider<List<AssetItem>>((ref) async {
  ref.watch(assetVersionProvider);
  final dao = ref.read(assetDaoProvider);
  return dao.getFavorites();
});

/// 物品列表 provider（依赖 assetVersionProvider 实现自动刷新）
final assetListProvider = FutureProvider<List<AssetItem>>((ref) async {
  ref.watch(assetVersionProvider);
  final dao = ref.read(assetDaoProvider);
  return dao.getAll();
});

/// 搜索 provider
final searchQueryProvider = StateProvider<String>((ref) => '');

/// 搜索结果 provider
final searchResultsProvider =
    FutureProvider.family<List<AssetItem>, String>(
  (ref, query) async {
    ref.watch(assetVersionProvider);
    if (query.isEmpty) {
      final dao = ref.read(assetDaoProvider);
      return dao.getAll();
    }
    final dao = ref.read(assetDaoProvider);
    return dao.search(query);
  },
);

/// 分类过滤 provider
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// 按分类过滤的物品
final filteredByCategoryProvider =
    FutureProvider.family<List<AssetItem>, String?>(
  (ref, category) async {
    ref.watch(assetVersionProvider);
    final dao = ref.read(assetDaoProvider);
    if (category == null || category.isEmpty) {
      return dao.getAll();
    }
    return dao.getByCategory(category);
  },
);

/// 统计数据 provider
/// 统计范围：all=全部 active=使用中 archived=已归档
final statsScopeProvider = StateProvider<String>((ref) => 'active');

/// 统计时间范围月数：0=全部
final statsMonthsProvider = StateProvider<int>((ref) => 0);

/// 首页总览统计（始终使用「使用中」范围，不受统计页过滤影响）
final homeStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(assetVersionProvider);
  final dao = ref.read(assetDaoProvider);
  return dao.getStatistics(scope: 'active', months: 0);
});

/// 统计页详情统计（可切换范围和时间）
final statisticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(assetVersionProvider);
  final scope = ref.watch(statsScopeProvider);
  final months = ref.watch(statsMonthsProvider);
  final dao = ref.read(assetDaoProvider);
  return dao.getStatistics(scope: scope, months: months);
});

/// 物品详情 provider
final assetDetailProvider =
    FutureProvider.family<AssetItem?, int>((ref, id) async {
  ref.watch(assetVersionProvider);
  final dao = ref.read(assetDaoProvider);
  return dao.getById(id);
});

/// 分页配置
final pageSizeProvider = StateProvider<int>((ref) => 20);
final currentPageProvider = StateProvider<int>((ref) => 0);

/// 分页物品列表
final pagedAssetListProvider = FutureProvider<List<AssetItem>>((ref) async {
  ref.watch(assetVersionProvider);
  final dao = ref.read(assetDaoProvider);
  final page = ref.watch(currentPageProvider);
  final pageSize = ref.watch(pageSizeProvider);
  return dao.getPaged(page, pageSize);
});

/// 物品总数
final assetCountProvider = FutureProvider<int>((ref) async {
  ref.watch(assetVersionProvider);
  final dao = ref.read(assetDaoProvider);
  return dao.getCount();
});

/// 工具 extension — 数据变更后调用 bumpVersion() 自动刷新所有列表/统计
extension BumpVersion on WidgetRef {
  void bumpVersion() => read(assetVersionProvider.notifier).state++;
}
