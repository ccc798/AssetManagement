import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/i18n/translations.dart';
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

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sel = ref.watch(selectedCategoryProvider);
        return Scaffold(
      appBar: AppBar(
        title: _isSearching ? _buildSearchField() : Text(t('home.title', ref.read(localeCodeProvider))),
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
      ),
      body: Column(children: [_buildStatsBanner(), _buildCategoryFilter(), Expanded(child: _buildAssetList())]),
      floatingActionButton: sel == '__archived__' || sel == '__deleted__'
          ? null
          : FloatingActionButton(
        onPressed: () async {
          final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddItemPage()));
          if (r == true) ref.bumpVersion();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchField() => TextField(
    controller: _searchController, autofocus: true,
    decoration: InputDecoration(hintText: t('home.searchHint', ref.read(localeCodeProvider)), border: InputBorder.none, filled: false),
    // Note: _buildSearchField uses ref.read because it's called from build which has loc via ref.watch
    onChanged: (v) { ref.read(searchQueryProvider.notifier).state = v; ref.invalidate(searchResultsProvider(v)); },
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
    final async = q.isNotEmpty ? ref.watch(searchResultsProvider(q))
        : archived ? ref.watch(archivedListProvider)
        : deleted ? ref.watch(deletedListProvider)
        : sel != null ? ref.watch(filteredByCategoryProvider(sel))
        : ref.watch(assetListProvider);
    return async.when(
      data: (items) {
        if (items.isEmpty) {
          if (q.isNotEmpty) return EmptyStateWidget(title: t('home.noMatch', ref.read(localeCodeProvider)), subtitle: t('home.noMatchHint', ref.read(localeCodeProvider)), customPainterSize: 120);
          return EmptyStateWidget(title: t('home.empty', ref.read(localeCodeProvider)), subtitle: t('home.emptyHint', ref.read(localeCodeProvider)));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.bumpVersion(),
          child: ListView.builder(padding: const EdgeInsets.only(top: 4, bottom: 80), itemCount: items.length, itemBuilder: (ctx, i) {
            final item = items[i];
            return AssetCard(
              item: item,
              onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailPage(item: item))); ref.bumpVersion(); },
              onEdit: deleted ? null : () async { final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddItemPage(editItem: item))); if (r == true) ref.bumpVersion(); },
              onArchive: archived ? null : () => _confirmArchive(item),
              onDelete: deleted ? () => _confirmHardDelete(item) : () => _confirmDelete(item),
            );
          }),
        );
      },
      loading: () => LoadingWidget(message: t('home.loading', ref.read(localeCodeProvider))),
      error: (err, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 16), Text('${t('home.loadFailed', ref.read(localeCodeProvider))}: $err')])),
    );
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
