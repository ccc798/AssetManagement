import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/i18n/translations.dart';
import '../../../core/services/image_service.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money_utils.dart';
import '../../../data/models/asset_item.dart';
import '../../providers/asset_provider.dart';
import '../../widgets/app_toast.dart';
import '../image_viewer/image_viewer_page.dart';

/// 物品详情页
class ItemDetailPage extends ConsumerStatefulWidget {
  final AssetItem item;

  const ItemDetailPage({super.key, required this.item});

  @override
  ConsumerState<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends ConsumerState<ItemDetailPage> {
  AssetItem? _currentItem;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
  }

  @override
  Widget build(BuildContext context) {
    final item = _currentItem ?? widget.item;
    
    return Consumer(
      builder: (context, ref, child) {
        final theme = Theme.of(context);
        final loc = ref.read(localeCodeProvider);
        final days = item.daysUsed;
        final cost = item.dailyCost;
        final remainingRatio = item.remainingValueRatio;
        final endDate = item.estimatedEndDate;

        return Scaffold(
          appBar: AppBar(
            title: Text(item.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.archive_outlined),
                onPressed: () => _confirmArchive(context, ref, item, loc),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderCard(theme, item, days, cost, remainingRatio, loc),
              const SizedBox(height: 16),

              if (item.images.isNotEmpty) ...[
                _buildImagesCard(context, theme, item, loc),
                const SizedBox(height: 16),
              ],

              _buildDetailCard(theme, item, loc),
              const SizedBox(height: 16),

              _buildValueAnalysisCard(theme, item, days, cost, endDate, loc),
              const SizedBox(height: 16),

              if (item.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildNotesCard(theme, item, loc),
              ],

              if (item.relatedItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildRelatedItemsCard(context, ref, theme, loc),
              ],

            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(
    ThemeData theme,
    AssetItem item,
    int days,
    double cost,
    double remainingRatio,
    String loc,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                AppIcons.getIcon(_getCategoryIcon(item.category)),
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    MoneyUtils.format(item.price, locale: loc),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t('detail.purchased', loc).replaceAll('{date}', AppDateUtils.formatLocale(item.purchaseDate ?? DateTime.now(), loc)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        t('detail.usedDays', loc).replaceAll('{days}', '$days'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildValueIndicator(theme, remainingRatio, loc),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueIndicator(ThemeData theme, double ratio, String loc) {
    final color = ratio > 0.5
        ? Colors.green
        : ratio > 0.2
            ? Colors.orange
            : Colors.red;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 4),
        Text(
          t('detail.remainingValue', loc).replaceAll('{pct}', '${(ratio * 100).toInt()}'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildImagesCard(BuildContext context, ThemeData theme, AssetItem item, String loc) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('detail.images', loc),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.images.asMap().entries.map((entry) {
                final index = entry.key;
                final path = entry.value;
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ImageViewerPage(
                          imagePaths: item.images,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'image_$index',
                    child: ImageService.instance.buildImageThumbnail(path, size: 100),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(ThemeData theme, AssetItem item, String loc) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('detail.details', loc),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Divider(),
            _detailRow(t('detail.category', loc), t(AppConstants.getCategoryNameKey(item.category), loc), AppIcons.getIcon(
                _getCategoryIcon(item.category),
              )),
            if (item.brand.isNotEmpty)
              _detailRow(t('detail.brand', loc), item.brand, Icons.business),
            _detailRow(
              t('detail.purchaseDate', loc),
              AppDateUtils.formatLocale(item.purchaseDate ?? DateTime.now(), loc),
              Icons.calendar_today,
            ),
            _detailRow(
              t('detail.lifetime', loc),
              '${item.plannedLifetimeDays}${t('unit.day', loc)} (${t('add.about', loc)} ${(item.plannedLifetimeDays / 365).toStringAsFixed(1)}${t('add.years', loc)})',
              Icons.schedule,
            ),
            if (item.rating > 0)
              _detailRow(
                t('detail.rating', loc),
                '⭐' * item.rating,
                Icons.star,
              ),
            if (item.warrantyPeriod != null && item.warrantyPeriod!.isNotEmpty)
              _detailRow(t('detail.warrantyPeriod', loc), item.warrantyPeriod!, Icons.verified),
            if (item.warrantyExpiry != null)
              _detailRow(
                t('detail.warrantyExpiry', loc),
                '${item.warrantyExpiry!.year}-${item.warrantyExpiry!.month.toString().padLeft(2, '0')}-${item.warrantyExpiry!.day.toString().padLeft(2, '0')}',
                Icons.event,
              ),
            if (item.insuranceInfo != null && item.insuranceInfo!.isNotEmpty)
              _detailRow(t('detail.insurance', loc), item.insuranceInfo!, Icons.security),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueAnalysisCard(
    ThemeData theme,
    AssetItem item,
    int days,
    double cost,
    DateTime? endDate,
    String loc,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('detail.costAnalysis', loc),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Divider(),
            _buildCostRow(
              t('detail.purchasePrice', loc),
              MoneyUtils.format(item.price, locale: loc),
              Icons.monetization_on,
              Colors.blue,
            ),
            _buildCostRow(
              t('detail.usedDaysLabel', loc),
              '$days${t('unit.day', loc)}',
              Icons.timer,
              Colors.teal,
            ),
            _buildCostRow(
              t('detail.dailyCost', loc),
              MoneyUtils.dailyCostDescription(cost, locale: loc),
              Icons.trending_down,
              cost < 1 ? Colors.green : Colors.orange,
            ),
            _buildCostRow(
              t('detail.dailyAnalogy', loc),
              MoneyUtils.dailyCostAnalogy(cost, locale: loc),
              Icons.coffee,
              Colors.brown,
            ),
            if (endDate != null) ...[
              const Divider(),
              _buildCostRow(
                t('detail.estimatedEnd', loc),
                AppDateUtils.formatLocale(endDate, loc),
                Icons.event,
                Colors.red.shade300,
              ),
              _buildCostRow(
                t('detail.remainingDays', loc),
                '${(endDate.difference(DateTime.now()).inDays > 0 ? endDate.difference(DateTime.now()).inDays : 0)}${t('unit.day', loc)}',
                Icons.hourglass_bottom,
                Colors.purple,
              ),
            ],
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 1 - item.remainingValueRatio,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  item.remainingValueRatio > 0.5
                      ? Colors.green
                      : item.remainingValueRatio > 0.2
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t('detail.usageProgress', loc)
                .replaceAll('{used}', (days / item.plannedLifetimeDays * 100).toStringAsFixed(0))
                .replaceAll('{remaining}', (item.remainingValueRatio * 100).toStringAsFixed(0)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(ThemeData theme, AssetItem item, String loc) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('detail.notes', loc),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(item.notes),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedItemsCard(BuildContext context, WidgetRef ref, ThemeData theme, String loc) {
    final item = _currentItem ?? widget.item;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('related.title', loc),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            ...item.relatedItems.map((uuid) {
                return FutureBuilder<AssetItem?>(
                  future: ref.read(assetDaoProvider).getByUuid(uuid),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const SizedBox.shrink();
                    }
                    final relatedItem = snapshot.data!;
                    return ListTile(
                      key: Key(uuid),
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          AppIcons.getIcon(_getCategoryIcon(relatedItem.category)),
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(relatedItem.name),
                      subtitle: Text(
                        MoneyUtils.format(relatedItem.price, locale: loc),
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ItemDetailPage(item: relatedItem),
                          ),
                        );
                      },
                    );
                  },
                );
              }),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('related.totalValue', loc),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                FutureBuilder<double>(
                  future: _calculateRelatedTotalValue(ref),
                  builder: (context, snapshot) {
                    final total = snapshot.data ?? 0.0;
                    return Text(
                      MoneyUtils.format(total, locale: loc),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<double> _calculateRelatedTotalValue(WidgetRef ref) async {
    final item = _currentItem ?? widget.item;
    double total = 0.0;
    for (final uuid in item.relatedItems) {
      final relatedItem = await ref.read(assetDaoProvider).getByUuid(uuid);
      if (relatedItem != null) {
        total += relatedItem.price;
      }
    }
    return total;
  }

  void _confirmArchive(BuildContext context, WidgetRef ref, AssetItem item, String loc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('confirm.archiveTitle', loc)),
        content: Text(t('confirm.archiveContent', loc).replaceAll('{name}', item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('confirm.cancel', loc)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final dao = ref.read(assetDaoProvider);
              await dao.update(item.copyWith(isArchived: true));
              ref.bumpVersion();
              if (context.mounted) {
                AppToast.capsule(context, t('toast.archived', loc), Colors.blue);
                Navigator.pop(context);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text(t('confirm.archive', loc)),
          ),
        ],
      ),
    );
  }

  String _getCategoryIcon(String category) {
    return AppConstants.getCategoryIconName(category);
  }
}