import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/i18n/translations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../data/database/asset_dao.dart';
import '../../../data/database/category_dao.dart';
import '../../../data/models/category.dart';
import '../../providers/category_provider.dart';
import '../../widgets/app_toast.dart';

/// 分类管理页面
class CategoryManagementPage extends ConsumerWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc2 = ref.read(localeCodeProvider);
    final async = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('category.title', loc2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditDialog(context, ref, null),
          ),
        ],
      ),
      body: async.when(
        data: (categories) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          itemBuilder: (ctx, i) {
            final cat = categories[i];
            final color = _parseColor(cat.colorHex);
            return Card(
              child: ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(AppIcons.getIcon(cat.icon), color: color, size: 22),
                ),
                title: Text(
                  cat.isPreset ? t(AppConstants.getCategoryNameKey(cat.name), loc2) : cat.name,
                  style: TextStyle(
                  decoration: cat.isDeleted ? TextDecoration.lineThrough : null,
                  color: cat.isDeleted ? Colors.grey : null,
                )),
                subtitle: Text(
                  cat.isPreset ? t('category.preset', loc2) : t('category.custom', loc2),
                  style: TextStyle(fontSize: 12, color: cat.isDeleted ? Colors.grey[400] : Colors.grey),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _showEditDialog(context, ref, cat),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]),
                      onPressed: () => _confirmDelete(context, ref, cat),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('${t('error.loadFailed', ref.read(localeCodeProvider))}: $err')),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, CategoryItem? existing) {
    final loc = ref.read(localeCodeProvider);
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String selectedIcon = existing?.icon ?? 'other';
    String selectedColor = existing?.colorHex ?? '#9E9E9E';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? t('category.editTitle', loc) : t('category.addTitle', loc)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 名称
                  if (existing == null || !existing.isPreset)
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: t('category.nameLabel', loc),
                        hintText: t('category.nameHint', loc),
                        isDense: true,
                      ),
                    )
                  else
                    Text(existing.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // 图标选择
                  Text(t('category.iconLabel', loc), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: iconKeys.map((key) {
                      final isSel = selectedIcon == key;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIcon = key),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: isSel ? _parseColor(selectedColor).withValues(alpha: 0.2) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: isSel ? Border.all(color: _parseColor(selectedColor), width: 2) : null,
                          ),
                          child: Icon(AppIcons.getIcon(key), color: isSel ? _parseColor(selectedColor) : Colors.grey[600], size: 22),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 颜色选择
                  Text(t('category.colorLabel', loc), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colorPresets.map((hex) {
                      final isSel = selectedColor == hex;
                      final c = _parseColor(hex);
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = hex),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                            boxShadow: isSel ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)] : null,
                          ),
                          child: isSel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('confirm.cancel', loc))),
            TextButton(
              onPressed: () async {
                if (existing == null || !existing.isPreset) {
                  if (nameCtrl.text.trim().isEmpty) return;
                }
                try {
                  final dao = CategoryDao();
                  if (existing != null) {
                    await dao.update(existing.id,
                        name: existing.isPreset ? null : nameCtrl.text.trim(),
                        icon: selectedIcon,
                        colorHex: selectedColor);
                  } else {
                    await dao.add(nameCtrl.text.trim(), selectedIcon, selectedColor);
                  }
                  ref.read(categoryVersionProvider.notifier).state++;
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    AppToast.capsule(context, existing != null ? t('toast.updated', loc) : t('toast.added', loc), Colors.green);
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppToast.capsule(context, '${t('error.loadFailed', loc)}: $e', Colors.red);
                  }
                }
              },
              child: Text(existing != null ? t('category.save', loc) : t('category.add', loc)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CategoryItem cat) {
    final loc3 = ref.read(localeCodeProvider);
    final displayName = cat.isPreset
        ? t(AppConstants.getCategoryNameKey(cat.name), loc3)
        : cat.name;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('category.deleteConfirm', loc3).replaceAll('{name}', displayName)),
        content: Text(t('category.deleteConfirm', loc3).replaceAll('{name}', displayName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('confirm.cancel', loc3))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _checkAndConfirmDelete(context, ref, cat);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t('confirm.delete', loc3)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndConfirmDelete(BuildContext context, WidgetRef ref, CategoryItem cat) async {
    // 查询该分类下的物品
    final dao = AssetDao.instance;
    final items = await dao.getByCategoryAll(cat.name);
    final loc4 = ref.read(localeCodeProvider);
    final displayName2 = cat.isPreset
        ? t(AppConstants.getCategoryNameKey(cat.name), loc4)
        : cat.name;

    if (!context.mounted) return;

    if (items.isEmpty) {
      // 没有物品，直接二次确认
      _doFinalDelete(context, ref, cat, 0);
    } else {
      // 有物品，需明确提示
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('category.hasItems', loc4)),
          content: Text(
            t('category.hasItemsDesc', loc4)
                .replaceAll('{name}', displayName2)
                .replaceAll('{n}', '${items.length}'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('confirm.cancel', loc4))),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _doFinalDelete(context, ref, cat, items.length);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(t('category.deleteCategoryItems', loc4)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _doFinalDelete(BuildContext context, WidgetRef ref, CategoryItem cat, int itemCount) async {
    try {
      // 1. 删除该分类下的所有物品（硬删除）
      final dao = AssetDao.instance;
      await dao.deleteByCategory(cat.name);
      // 2. 删除分类本身
      await CategoryDao().delete(cat.id);
      // 3. 刷新
      ref.read(categoryVersionProvider.notifier).state++;
      if (context.mounted) {
        final loc4 = ref.read(localeCodeProvider);
        final msg = itemCount > 0
            ? t('category.deletedWith', loc4).replaceAll('{n}', '$itemCount')
            : t('category.deleted', loc4);
        AppToast.capsule(context, msg, Colors.green);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.capsule(context, '${t('error.loadFailed', ref.read(localeCodeProvider))}: $e', Colors.red);
      }
    }
  }

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

/// 可用图标键列表
const iconKeys = [
  'electronics', 'clothing', 'food', 'home', 'book', 'sports',
  'beauty', 'transport', 'medical', 'gift', 'pet', 'other',
];

/// 预设颜色
const colorPresets = [
  '#2196F3', '#E91E63', '#FF9800', '#4CAF50',
  '#9C27B0', '#00BCD4', '#F44336', '#607D8B',
  '#795548', '#FF5722', '#F06292', '#9E9E9E',
];
