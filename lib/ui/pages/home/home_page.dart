import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/i18n/translations.dart';
import '../../../core/theme/app_icons.dart';
import '../../providers/asset_provider.dart';
import '../../providers/category_provider.dart';
import '../../widgets/asset_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/app_toast.dart';
import '../../../core/operations.dart';
import '../../../core/utils/money_utils.dart';
import '../../../data/models/asset_item.dart';
import '../add_item/add_item_page.dart';
import '../item_detail/item_detail_page.dart';
import '../statistics/statistics_page.dart';
import '../settings/settings_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isSelectMode = false;
  final Set<int> _selectedIds = {};

  @override
  void dispose() { 
    _searchController.dispose(); 
    super.dispose(); 
  }

  void _toggleSelectMode(bool enabled) {
    setState(() {
      _isSelectMode = enabled;
      if (!enabled) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleItemSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<AssetItem> items) {
    setState(() {
      _selectedIds.addAll(items.map((item) => item.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final sel = ref.watch(selectedCategoryProvider);
    final theme = Theme.of(context);
    final loc = ref.read(localeCodeProvider);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _isSelectMode ? _buildSelectModeAppBar(loc, theme) : _buildNormalAppBar(loc),
      ),
      body: Column(children: [_buildStatsBanner(), _buildCategoryFilter(), Expanded(child: _buildAssetList())]),
      floatingActionButton: !_isSelectMode && sel != '__archived__' && sel != '__deleted__'
          ? FloatingActionButton(
        onPressed: () async {
          final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddItemPage()));
          if (r == true) ref.bumpVersion();
        },
        child: const Icon(Icons.add),
      )
          : null,
      bottomSheet: _isSelectMode && _selectedIds.isNotEmpty ? _buildBatchActionBar(loc, theme) : null,
    );
  }

  Widget _buildNormalAppBar(String loc) => AppBar(
    title: _isSearching ? _buildSearchField() : Text(t('home.title', loc)),
    actions: [
      if (_isSearching)
        IconButton(icon: const Icon(Icons.close), onPressed: () {
          setState(() { _isSearching = false; _searchController.clear(); });
          ref.read(searchQueryProvider.notifier).state = '';
        })
      else ...[
        IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _isSearching = true)),
        IconButton(icon: const Icon(Icons.bar_chart), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsPage()))),
        IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()))),
      ],
    ],
  );

  Widget _buildSelectModeAppBar(String loc, ThemeData theme) => AppBar(
    leading: IconButton(
      icon: const Icon(Icons.close),
      onPressed: () => _toggleSelectMode(false),
    ),
    title: Text('${_selectedIds.length} ${t('select.selected', loc)}'),
    actions: [
      TextButton(
        onPressed: () {
          final sel = ref.watch(selectedCategoryProvider);
          final q = ref.watch(searchQueryProvider);
          final async = q.isNotEmpty ? ref.read(searchResultsProvider(q))
              : sel == '__archived__' ? ref.read(archivedListProvider)
              : sel == '__deleted__' ? ref.read(deletedListProvider)
              : sel == '__favorite__' ? ref.read(favoriteListProvider)
              : sel != null ? ref.read(filteredByCategoryProvider(sel))
              : ref.read(assetListProvider);
          async.whenData((items) => _selectAll(items));
        },
        child: Text(t('select.all', loc)),
      ),
    ],
    backgroundColor: theme.colorScheme.primary,
    foregroundColor: Colors.white,
  );

  Widget _buildSearchField() => TextField(
    controller: _searchController, autofocus: true,
    decoration: InputDecoration(hintText: t('home.searchHint', ref.read(localeCodeProvider)), border: InputBorder.none, filled: false),
    onChanged: (v) { ref.read(searchQueryProvider.notifier).state = v; ref.invalidate(searchResultsProvider(v)); },
  );

  Widget _buildBatchActionBar(String loc, ThemeData theme) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      border: Border(top: BorderSide(color: theme.dividerColor)),
    ),
    child: Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _showBatchCategoryDialog(loc),
            child: Text(t('batch.changeCategory', loc)),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          onPressed: () => _batchArchive(loc),
          child: Text(t('batch.archive', loc)),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => _batchDelete(loc),
          child: Text(t('batch.delete', loc)),
        ),
      ],
    ),
  );

  Widget _buildStatsBanner() {
    final theme = Theme.of(context);
    final loc2 = ref.read(localeCodeProvider);
    return ref.watch(homeStatsProvider).when(
      data: (s) {
        final c = s['totalCount'] as int; final p = s['totalPrice'] as double; final d = s['dailyAvgCost'] as double;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)]), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('home.totalAssets', ref.read(localeCodeProvider)), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Text(MoneyUtils.format(p, locale: loc2), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              _miniStat(Icons.inventory_2, '$c${t('home.pieces', ref.read(localeCodeProvider))}'), const SizedBox(width: 16),
              _miniStat(Icons.trending_down, MoneyUtils.dailyCostDescription(d, locale: loc2)),
            ]),
          ]),
        );
      },
      loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _miniStat(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, color: Colors.white70, size: 14), const SizedBox(width: 4), Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12))],
  );

  Widget _buildCategoryFilter() {
    final theme = Theme.of(context);
    final cats = ref.watch(categoryListProvider);
    final sel = ref.watch(selectedCategoryProvider);
    return cats.when(
      data: (list) => Container(
        height: 56, margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          GestureDetector(onTap: () { ref.read(selectedCategoryProvider.notifier).state = null; ref.invalidate(filteredByCategoryProvider(null)); },
            child: Container(
              margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), alignment: Alignment.center,
              decoration: BoxDecoration(color: sel == null ? theme.colorScheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(24),
                border: Border.all(color: sel == null ? theme.colorScheme.primary : theme.dividerColor)),
              child: Text(t('home.all', ref.read(localeCodeProvider)), style: TextStyle(color: sel == null ? Colors.white : theme.colorScheme.onSurface, fontWeight: sel == null ? FontWeight.w600 : FontWeight.normal)),
            )),
          ...list.map((cat) => Padding(padding: const EdgeInsets.only(right: 8), child: CategoryChip(
            name: t(AppConstants.getCategoryNameKey(cat.name), ref.read(localeCodeProvider)),
            iconName: cat.icon, colorHex: cat.colorHex, isSelected: sel == cat.name,
            onTap: () { ref.read(selectedCategoryProvider.notifier).state = cat.name; ref.invalidate(filteredByCategoryProvider(cat.name)); },
          ))),
          GestureDetector(onTap: () => ref.read(selectedCategoryProvider.notifier).state = '__archived__',
            child: Container(
              margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), alignment: Alignment.center,
              decoration: BoxDecoration(color: sel == '__archived__' ? Colors.grey : Colors.transparent, borderRadius: BorderRadius.circular(24),
                border: Border.all(color: sel == '__archived__' ? Colors.grey : theme.dividerColor)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.archive, size: 16, color: sel == '__archived__' ? Colors.white : Colors.grey),
                const SizedBox(width: 6),
                Text(t('home.archived', ref.read(localeCodeProvider)), style: TextStyle(color: sel == '__archived__' ? Colors.white : theme.colorScheme.onSurface, fontWeight: sel == '__archived__' ? FontWeight.w600 : FontWeight.normal)),
              ]),
            )),
          GestureDetector(onTap: () => ref.read(selectedCategoryProvider.notifier).state = '__favorite__',
            child: Container(
              margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), alignment: Alignment.center,
              decoration: BoxDecoration(color: sel == '__favorite__' ? Colors.amber : Colors.transparent, borderRadius: BorderRadius.circular(24),
                border: Border.all(color: sel == '__favorite__' ? Colors.amber : theme.dividerColor)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star, size: 16, color: sel == '__favorite__' ? Colors.white : Colors.amber),
                const SizedBox(width: 6),
                Text(t('home.favorite', ref.read(localeCodeProvider)), style: TextStyle(color: sel == '__favorite__' ? Colors.white : theme.colorScheme.onSurface, fontWeight: sel == '__favorite__' ? FontWeight.w600 : FontWeight.normal)),
              ]),
            )),
          GestureDetector(onTap: () => ref.read(selectedCategoryProvider.notifier).state = '__deleted__',
            child: Container(
              margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), alignment: Alignment.center,
              decoration: BoxDecoration(color: sel == '__deleted__' ? Colors.red : Colors.transparent, borderRadius: BorderRadius.circular(24),
                border: Border.all(color: sel == '__deleted__' ? Colors.red : theme.dividerColor)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.delete_outline, size: 16, color: sel == '__deleted__' ? Colors.white : Colors.red[300]),
                const SizedBox(width: 6),
                Text(t('home.deleted', ref.read(localeCodeProvider)), style: TextStyle(color: sel == '__deleted__' ? Colors.white : Colors.red[300], fontWeight: sel == '__deleted__' ? FontWeight.w600 : FontWeight.normal)),
              ]),
            )),
        ]),
      ),
      loading: () => const SizedBox(height: 56), error: (_, __) => const SizedBox(height: 56),
    );
  }

  Widget _buildAssetList() {
    final sel = ref.watch(selectedCategoryProvider);
    final q = ref.watch(searchQueryProvider);
    final archived = sel == '__archived__';
    final deleted = sel == '__deleted__';
    final favorite = sel == '__favorite__';
    final async = q.isNotEmpty ? ref.watch(searchResultsProvider(q))
        : archived ? ref.watch(archivedListProvider)
        : deleted ? ref.watch(deletedListProvider)
        : favorite ? ref.watch(favoriteListProvider)
        : sel != null ? ref.watch(filteredByCategoryProvider(sel))
        : ref.watch(assetListProvider);
    return async.when(
      data: (items) {
        if (items.isEmpty) {
          if (q.isNotEmpty) return EmptyStateWidget(title: t('home.noMatch', ref.read(localeCodeProvider)), subtitle: t('home.noMatchHint', ref.read(localeCodeProvider)), customPainterSize: 120);
          if (favorite) return EmptyStateWidget(title: t('favorite.empty', ref.read(localeCodeProvider)), subtitle: t('favorite.emptyHint', ref.read(localeCodeProvider)), customPainterSize: 120);
          return EmptyStateWidget(title: t('home.empty', ref.read(localeCodeProvider)), subtitle: t('home.emptyHint', ref.read(localeCodeProvider)));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.bumpVersion(),
          child: ListView.builder(padding: EdgeInsets.only(top: 4, bottom: _isSelectMode ? 120 : 80), itemCount: items.length, itemBuilder: (ctx, i) {
            final item = items[i];
            return AssetCard(
              key: ObjectKey(item.id),
              item: item,
              isSelected: _isSelectMode && _selectedIds.contains(item.id),
              onTap: _isSelectMode ? () => _toggleItemSelection(item.id) : () async { 
                await Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailPage(item: item))); 
                ref.bumpVersion(); 
              },
              onLongPress: !_isSelectMode ? () {
                _toggleSelectMode(true);
                _selectedIds.add(item.id);
              } : null,
              onEdit: deleted ? null : () async { final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddItemPage(editItem: item))); if (r == true) ref.bumpVersion(); },
              onArchive: archived || favorite ? null : () => _confirmArchive(item),
              onDelete: deleted ? () => _confirmHardDelete(item) : () => _confirmDelete(item),
              onFavorite: deleted || archived ? null : () => _toggleFavorite(item),
            );
          }),
        );
      },
      loading: () => LoadingWidget(message: t('home.loading', ref.read(localeCodeProvider))),
      error: (err, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 16), Text('${t('home.loadFailed', ref.read(localeCodeProvider))}: $err')])),
    );
  }

  void _showBatchCategoryDialog(String loc) async {
    final cats = await ref.read(categoryListProvider.future);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(t('batch.changeCategory', loc)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: cats.map((cat) => ListTile(
          leading: AppIcons.categoryIcon(cat.icon, cat.colorHex),
          title: Text(t(AppConstants.getCategoryNameKey(cat.name), loc)),
          onTap: () async {
            Navigator.pop(ctx);
            await _batchUpdateCategory(cat.name, loc);
          },
        )).toList(),
      ),
    ));
  }

  Future<void> _batchUpdateCategory(String category, String loc) async {
    final dao = ref.read(assetDaoProvider);
    final count = _selectedIds.length;
    for (final id in _selectedIds) {
      final item = await dao.getById(id);
      if (item != null) {
        await dao.update(item.copyWith(category: category));
      }
    }
    _toggleSelectMode(false);
    ref.bumpVersion();
    if (mounted) {
      AppToast.capsule(context, t('batch.updated', loc).replaceAll('{n}', '$count'), Colors.green);
    }
  }

  void _batchArchive(String loc) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(t('confirm.archiveTitle', loc)),
      content: Text(t('batch.archiveConfirm', loc).replaceAll('{n}', '${_selectedIds.length}')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('confirm.cancel', loc))),
        TextButton(onPressed: () async {
          Navigator.pop(ctx);
          final dao = ref.read(assetDaoProvider);
          final count = _selectedIds.length;
          for (final id in _selectedIds) {
            final item = await dao.getById(id);
            if (item != null && !item.isArchived) {
              await dao.update(item.copyWith(isArchived: true));
            }
          }
          _toggleSelectMode(false);
          ref.bumpVersion();
          if (mounted) {
            AppToast.capsule(context, t('batch.archived', loc).replaceAll('{n}', '$count'), Colors.orange);
          }
        }, style: TextButton.styleFrom(foregroundColor: Colors.orange), child: Text(t('confirm.archive', loc))),
      ],
    ));
  }

  void _batchDelete(String loc) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(t('confirm.deleteTitle', loc)),
      content: Text(t('batch.deleteConfirm', loc).replaceAll('{n}', '${_selectedIds.length}')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('confirm.cancel', loc))),
        TextButton(onPressed: () async {
          Navigator.pop(ctx);
          final dao = ref.read(assetDaoProvider);
          final count = _selectedIds.length;
          for (final id in _selectedIds) {
            await dao.softDelete(id);
          }
          _toggleSelectMode(false);
          ref.bumpVersion();
          if (mounted) {
            AppToast.capsule(context, t('batch.deleted', loc).replaceAll('{n}', '$count'), Colors.red);
          }
        }, style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(t('confirm.delete', loc))),
      ],
    ));
  }

  void _toggleFavorite(AssetItem item) async {
    final dao = ref.read(assetDaoProvider);
    await dao.toggleFavorite(item.id);
    ref.bumpVersion();
    if (mounted) {
      final loc2 = ref.read(localeCodeProvider);
      AppToast.capsule(
        context,
        item.isFavorite ? t('favorite.remove', loc2) : t('favorite.add', loc2),
        Colors.amber,
      );
    }
  }

  void _confirmArchive(AssetItem item) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(t('confirm.archiveTitle', ref.read(localeCodeProvider))),
      content: Text(t('confirm.archiveContent', ref.read(localeCodeProvider)).replaceAll('{name}', item.name)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('confirm.cancel', ref.read(localeCodeProvider)))),
        TextButton(onPressed: () async { Navigator.pop(ctx); await ItemOp.archive(ref, context, item); },
          style: TextButton.styleFrom(foregroundColor: Colors.orange), child: Text(t('confirm.archive', ref.read(localeCodeProvider)))),
      ],
    ));
  }

  void _confirmDelete(AssetItem item) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(t('confirm.deleteTitle', ref.read(localeCodeProvider))),
      content: Text(t('confirm.deleteContent', ref.read(localeCodeProvider)).replaceAll('{name}', item.name)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('confirm.cancel', ref.read(localeCodeProvider)))),
        TextButton(onPressed: () async { Navigator.pop(ctx); await ItemOp.delete(ref, context, item); },
          style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(t('confirm.delete', ref.read(localeCodeProvider)))),
      ],
    ));
  }

  void _confirmHardDelete(AssetItem item) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(t('confirm.hardDeleteTitle', ref.read(localeCodeProvider))),
      content: Text(t('confirm.hardDeleteContent', ref.read(localeCodeProvider)).replaceAll('{name}', item.name)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('confirm.cancel', ref.read(localeCodeProvider)))),
        TextButton(onPressed: () async {
          Navigator.pop(ctx);
          final dao = ref.read(assetDaoProvider);
          await dao.hardDelete(item.id);
          ref.bumpVersion();
          if (mounted) {
            AppToast.capsule(context, t('toast.hardDeleted', ref.read(localeCodeProvider)), Colors.red);
          }
        },
          style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(t('confirm.hardDelete', ref.read(localeCodeProvider)), style: const TextStyle(fontWeight: FontWeight.bold))),
      ],
    ));
  }
}