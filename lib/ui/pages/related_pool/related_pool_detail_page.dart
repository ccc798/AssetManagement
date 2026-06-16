import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/translations.dart';
import '../../../core/utils/money_utils.dart';
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pool = widget.pool;
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final dao = AssetDao.instance;
      final items = await Future.wait(
        _pool.itemUuids.map((uuid) => dao.getByUuid(uuid)),
      );
      _items = items.whereType<AssetItem>().toList();
    } catch (e) {
      setState(() {
        _errorMessage = t('error.loadFailed', ref.read(localeCodeProvider));
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshPool() async {
    try {
      final updatedPool = await RelatedPoolDao.instance.getByUuid(_pool.uuid);
      if (updatedPool != null) {
        _pool = updatedPool;
        _loadItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('error.loadFailed', ref.read(localeCodeProvider)))),
        );
      }
    }
  }

  Future<void> _addItem(String itemUuid) async {
    if (widget.isReadOnly) return;
    
    try {
      await RelatedPoolDao.instance.addItem(_pool.uuid, itemUuid);
      _refreshPool();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('error.loadFailed', ref.read(localeCodeProvider)))),
        );
      }
    }
  }

  Future<void> _removeItem(String itemUuid) async {
    if (widget.isReadOnly) return;
    
    try {
      await RelatedPoolDao.instance.removeItem(_pool.uuid, itemUuid);
      _refreshPool();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('error.loadFailed', ref.read(localeCodeProvider)))),
        );
      }
    }
  }

  Future<void> _showAddItemDialog() async {
    if (widget.isReadOnly) return;
    
    final loc = ref.read(localeCodeProvider);
    
    try {
      final allItems = await AssetDao.instance.getAll();
      List<AssetItem> availableItems = allItems.where((i) => 
        !_pool.itemUuids.contains(i.uuid) && !i.isDeleted && !i.isArchived
      ).toList();

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
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
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.inventory_2, color: Theme.of(context).colorScheme.primary, size: 20),
                              ),
                              title: Text(item.name),
                              subtitle: Text(MoneyUtils.format(item.price, locale: loc)),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.green),
                                onPressed: () async {
                                  await RelatedPoolDao.instance.addItem(_pool.uuid, item.uuid);
                                  setState(() {
                                    availableItems.removeAt(index);
                                  });
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
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _refreshPool();
                    },
                    child: Text(t('confirm.ok', loc)),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('error.loadFailed', loc))),
        );
      }
    }
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
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
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
              '${t('relatedPool.totalPrice', loc)}: ${MoneyUtils.format(_getTotalPrice(), locale: loc)}',
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
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.inventory_2, color: theme.colorScheme.primary, size: 20),
              ),
              title: Text(item.name),
              subtitle: Text(MoneyUtils.format(item.price, locale: loc)),
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