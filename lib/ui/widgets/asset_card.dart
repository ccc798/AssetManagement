import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/translations.dart';
import '../../core/theme/app_icons.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/asset_item.dart';

/// 物品卡片组件 — 带滑动操作
class AssetCard extends ConsumerWidget {
  final AssetItem item;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;

  const AssetCard({
    super.key,
    required this.item,
    this.onTap,
    this.onDelete,
    this.onEdit,
    this.onArchive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final days = item.daysUsed;
    final cost = item.dailyCost;

    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          if (onEdit != null)
            SlidableAction(
              onPressed: (_) => onEdit?.call(),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: t('edit.label', ref.read(localeCodeProvider)),
            ),
          if (onArchive != null)
            SlidableAction(
              onPressed: (_) => onArchive?.call(),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              icon: Icons.archive_outlined,
              label: t('confirm.archive', ref.read(localeCodeProvider)),
            ),
          if (onDelete != null)
            SlidableAction(
              onPressed: (_) => onDelete?.call(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: t('confirm.delete', ref.read(localeCodeProvider)),
            ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 左侧图标
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(item.category).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    AppIcons.getIcon(
                      _getCategoryIcon(item.category),
                    ),
                    color: _getCategoryColor(item.category),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // 中间信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (item.brand.isNotEmpty) ...[
                            Text(
                              item.brand,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurfaceVariant,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            item.category,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _getCategoryColor(item.category),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 右侧价格信息
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      MoneyUtils.format(item.price, locale: ref.read(localeCodeProvider)),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$days${t('unit.day', ref.read(localeCodeProvider))} · ${MoneyUtils.dailyCostDescription(cost, locale: ref.read(localeCodeProvider))}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    return AppColors.fromHex(AppConstants.getCategoryColorHex(category));
  }

  String _getCategoryIcon(String category) {
    return AppConstants.getCategoryIconName(category);
  }
}
