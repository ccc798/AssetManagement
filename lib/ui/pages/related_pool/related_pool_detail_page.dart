import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/translations.dart';
import '../../../data/database/asset_dao.dart';
import '../../../data/database/related_pool_dao.dart';
import '../../../data/models/asset_item.dart';
import '../../../data/models/related_pool.dart';

class RelatedPoolDetailPage extends ConsumerStatefulWidget {
  final RelatedPool pool;
  final String currentItemUuid;
  final bool isReadOnly;

  const RelatedPoolDetailPage({
    super.key,
    required this.pool,
    required this.currentItemUuid,
    this.isReadOnly = false,
  });

  @override
  ConsumerState<RelatedPoolDetailPage> createState() => _RelatedPoolDetailPageState();
}

class _RelatedPoolDetailPageState extends ConsumerState<RelatedPoolDetailPage> {
  List<AssetItem> _items = [];
  RelatedPool _pool = RelatedPool(name: '', itemUuids: []);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pool = widget.pool;
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final dao = AssetDao.instance;
    final items = await Future.wait(
      _pool.itemUuids.map((uuid) => dao.getByUuid(uuid)),
    );
    _items = items.whereType<AssetItem>().toList();
    setState(() => _isLoading = false);
  }

  Future<void> _refreshPool() async {
    final updatedPool = await RelatedPoolDao.instance.getByUuid(_pool.uuid);
    if (updatedPool != null) {
      _pool = updatedPool;
      _loadItems();
    }
  }

  Future<void> _addItem(String itemUuid) async {
    if (widget.isReadOnly) return;
    
    await RelatedPoolDao.instance.addItem(_pool.uuid, itemUuid);
    _refreshPool();
  }

  Future<void> _removeItem(String itemUuid) async {
    if (widget.isReadOnly) return;
    
    await RelatedPoolDao.instance.removeItem(_pool.uuid, itemUuid);
    _refreshPool();
  }

  Future<void> _showAddItemDialog() async {
    if (widget.isReadOnly) return;
    
    final loc = ref.read(localeCodeProvider);
    final allItems = await AssetDao.instance.getAll();
    final availableItems = allItems.where((i) => 
      !_pool.itemUuids.contains(i.uuid) && !i.isDeleted && !i.isArchived
    ).toList();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(t('relatedPool.addItem', loc)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: availableItems.isEmpty
                ? Center(child: Text(t('relatedPool.noItems', loc)))
                : ListView.builder(
                    itemCount: availableItems.length,
                    itemBuilder: (context, index) {
                      final item = availableItems[index];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.inventory_2, color: Theme.of(context).colorScheme.primary, size: 20),
                        ),
                        title: Text(item.name),
                        subtitle: Text('¥${item.price.toStringAsFixed(2)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                          onPressed: () {
                            _addItem(item.uuid);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('confirm.cancel', loc)),
            ),
          ],
        );
      },
    );
  }

  double _getTotalPrice() {
    return _items.fold(0.0, (sum, item) => sum + item.price);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = ref.watch(localeCodeProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_pool.name),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildHeader(theme, loc),
                _buildItemList(theme, loc),
              ],
            ),
      floatingActionButton: !widget.isReadOnly
          ? FloatingActionButton(
              onPressed: _showAddItemDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildHeader(ThemeData theme, String loc) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t('relatedPool.itemCount', loc)}: ${_items.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${t('relatedPool.totalPrice', loc)}: ¥${_getTotalPrice().toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemList(ThemeData theme, String loc) {
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(t('relatedPool.empty', loc)),
        ),
      );
    }

    return Column(
      children: _items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.inventory_2, color: theme.colorScheme.primary, size: 20),
              ),
              title: Text(item.name),
              subtitle: Text('¥${item.price.toStringAsFixed(2)}'),
              trailing: !widget.isReadOnly
                  ? IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _removeItem(item.uuid),
                    )
                  : null,
              onTap: () {
                Navigator.pushNamed(context, '/item-detail', arguments: item);
              },
            ),
          ),
        );
      }).toList(),
    );
  }
}