import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/translations.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money_utils.dart';
import '../../providers/asset_provider.dart';

/// 统计页面
class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(statisticsProvider);
    final loc2 = ref.read(localeCodeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('statistics.title', loc2)),
      ),
      body: Column(
        children: [
          _buildFilters(context, ref),
          Expanded(
            child: statsAsync.when(
              data: (stats) {
                final totalCount = stats['totalCount'] as int;
                final totalPrice = stats['totalPrice'] as double;
                final avgPrice = stats['avgPrice'] as double;
                final maxPrice = stats['maxPrice'] as double;
                final minPrice = stats['minPrice'] as double;
                final dailyAvgCost = stats['dailyAvgCost'] as double;
                final categoryStats =
                    stats['categoryStats'] as Map<String, double>;
                final monthlyStats =
                    stats['monthlyStats'] as Map<String, double>;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildOverviewCard(theme, totalCount, totalPrice, dailyAvgCost, loc2),
                    const SizedBox(height: 16),
                    if (categoryStats.isNotEmpty) ...[
                      _buildCategoryStatsCard(theme, categoryStats, totalPrice, loc2),
                      const SizedBox(height: 16),
                    ],
                    if (monthlyStats.isNotEmpty) ...[
                      _buildMonthlyChartCard(theme, monthlyStats, loc2),
                      const SizedBox(height: 16),
                    ],
                    _buildDetailStatsCard(
                      theme, totalCount, totalPrice, avgPrice, maxPrice, minPrice, dailyAvgCost, loc2,
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('${t('error.loadFailed', ref.read(localeCodeProvider))}: $err'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(statsScopeProvider);
    final months = ref.watch(statsMonthsProvider);
    final loc2 = ref.read(localeCodeProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(t('statistics.scope', loc2), style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              _chip(context, t('statistics.scopeAll', loc2), scope == 'all', () => ref.read(statsScopeProvider.notifier).state = 'all'),
              const SizedBox(width: 6),
              _chip(context, t('statistics.scopeActive', loc2), scope == 'active', () => ref.read(statsScopeProvider.notifier).state = 'active'),
              const SizedBox(width: 6),
              _chip(context, t('statistics.scopeArchived', loc2), scope == 'archived', () => ref.read(statsScopeProvider.notifier).state = 'archived'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(t('statistics.time', loc2), style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              _chip(context, t('statistics.timeAll', loc2), months == 0, () => ref.read(statsMonthsProvider.notifier).state = 0),
              const SizedBox(width: 6),
              _chip(context, t('statistics.timeMonth', loc2), months == 1, () => ref.read(statsMonthsProvider.notifier).state = 1),
              const SizedBox(width: 6),
              _chip(context, t('statistics.time6m', loc2), months == 6, () => ref.read(statsMonthsProvider.notifier).state = 6),
              const SizedBox(width: 6),
              _chip(context, t('statistics.time1y', loc2), months == 12, () => ref.read(statsMonthsProvider.notifier).state = 12),
              const SizedBox(width: 6),
              _chip(context, t('statistics.time3y', loc2), months == 36, () => ref.read(statsMonthsProvider.notifier).state = 36),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, bool selected, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.transparent : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : null,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(ThemeData theme, int totalCount, double totalPrice, double dailyAvgCost, String loc2) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _overviewItem(theme, t('statistics.totalPrice', loc2), MoneyUtils.format(totalPrice, locale: loc2), Icons.account_balance_wallet, Colors.indigo),
                _overviewItem(theme, t('statistics.totalCount', loc2), '$totalCount${t('home.pieces', loc2)}', Icons.inventory_2, Colors.teal),
                _overviewItem(theme, t('statistics.avgPrice', loc2), MoneyUtils.format(dailyAvgCost, locale: loc2), Icons.trending_down, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewItem(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildCategoryStatsCard(ThemeData theme, Map<String, double> categoryStats, double totalPrice, String loc2) {
    final sorted = categoryStats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('statistics.categoryBreakdown', loc2), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...sorted.map((entry) {
              final percent = totalPrice > 0 ? (entry.value / totalPrice * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(width: 80, child: Text(entry.key, style: const TextStyle(fontSize: 13))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent / 100,
                          minHeight: 16,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.fromHex(AppConstants.getCategoryColorHex(entry.key))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 80, child: Text(MoneyUtils.formatCompact(entry.value, locale: loc2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    SizedBox(width: 48, child: Text('${percent.toStringAsFixed(1)}%', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyChartCard(ThemeData theme, Map<String, double> monthlyStats, String loc2) {
    final sortedMonths = monthlyStats.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (sortedMonths.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('statistics.monthlyTrend', loc2), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Center(child: Text(t('statistics.needMoreMonths', loc2))),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('statistics.monthlyTrend', loc2), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: _getChartInterval(sortedMonths)),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (v, m) => Text(MoneyUtils.formatCompact(v, locale: loc2), style: const TextStyle(fontSize: 10)))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 1, getTitlesWidget: (v, m) {
                      final i = v.toInt();
                      if (i >= 0 && i < sortedMonths.length) return Transform.rotate(angle: -0.5, child: Text(sortedMonths[i].key.substring(5), style: const TextStyle(fontSize: 10)));
                      return const Text('');
                    })),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: sortedMonths.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(show: true, getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 4, color: theme.colorScheme.primary, strokeWidth: 2, strokeColor: Colors.white)),
                      belowBarData: BarAreaData(show: true, color: theme.colorScheme.primary.withValues(alpha: 0.1)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getChartInterval(List<MapEntry<String, double>> data) {
    final maxVal = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0) return 1;
    final rough = maxVal / 4;
    if (rough <= 10) return 10;
    if (rough <= 100) return 100;
    if (rough <= 1000) return 1000;
    return (rough / 1000).ceilToDouble() * 1000;
  }

  Widget _buildDetailStatsCard(ThemeData theme, int totalCount, double totalPrice, double avgPrice, double maxPrice, double minPrice, double dailyAvgCost, String loc2) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('statistics.detail', loc2), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const Divider(),
            _detailStatRow(t('statistics.totalCount', loc2), '$totalCount${t('home.pieces', loc2)}'),
            _detailStatRow(t('statistics.totalPrice', loc2), MoneyUtils.format(totalPrice, locale: loc2)),
            _detailStatRow(t('statistics.avgPrice', loc2), MoneyUtils.format(avgPrice, locale: loc2)),
            _detailStatRow(t('statistics.maxPrice', loc2), MoneyUtils.format(maxPrice, locale: loc2)),
            _detailStatRow(t('statistics.minPrice', loc2), MoneyUtils.format(minPrice, locale: loc2)),
            _detailStatRow(t('statistics.avgPrice', loc2), MoneyUtils.format(dailyAvgCost, locale: loc2)),
          ],
        ),
      ),
    );
  }

  Widget _detailStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
