import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/translations.dart';
import '../../../core/utils/csv_export.dart';
import '../../providers/asset_provider.dart';
import '../../widgets/app_toast.dart';

/// 导出数据页面
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  String _scope = 'active'; // all / active / archived
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc2 = ref.read(localeCodeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t('export.title', loc2))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 说明
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t('export.desc', loc2),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 范围选择
            Text(t('export.scope', loc2), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                ChoiceChip(
                  label: Text(t('export.all', loc2)),
                  selected: _scope == 'all',
                  onSelected: (_) => setState(() => _scope = 'all'),
                ),
                ChoiceChip(
                  label: Text(t('export.active', loc2)),
                  selected: _scope == 'active',
                  onSelected: (_) => setState(() => _scope = 'active'),
                ),
                ChoiceChip(
                  label: Text(t('export.archived', loc2)),
                  selected: _scope == 'archived',
                  onSelected: (_) => setState(() => _scope = 'archived'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 字段预览
            Text(t('export.fields', loc2), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _fieldChip(t('add.name', loc2).replaceAll(' *', '')), _fieldChip(t('detail.category', loc2)), _fieldChip(t('add.brand', loc2)),
                    _fieldChip(t('add.price', loc2).replaceAll(' *', '')), _fieldChip(t('add.purchaseDate', loc2).replaceAll(' *', '')), _fieldChip(t('detail.usedDaysLabel', loc2)),
                    _fieldChip(t('detail.dailyCost', loc2)), _fieldChip(t('detail.remainingValue', loc2).split(' ')[0].replaceAll('{pct}', '')), _fieldChip(t('detail.lifetime', loc2)),
                    _fieldChip(t('detail.rating', loc2)), _fieldChip(t('add.notes', loc2)), _fieldChip(t('detail.notes', loc2)),
                    _fieldChip(t('detail.purchasePrice', loc2)),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // 导出按钮
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _doExport,
                icon: _isExporting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.file_download),
                label: Text(_isExporting ? t('export.exporting', loc2) : t('export.button', loc2)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _fieldChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    );
  }

  Future<void> _doExport() async {
    setState(() => _isExporting = true);
    final dao = ref.read(assetDaoProvider);

    final items = switch (_scope) {
      'all' => await dao.getAll(includeDeleted: true),
      'archived' => await dao.getArchived(),
      _ => await dao.getAll(),
    };

    if (items.isEmpty) {
      if (mounted) AppToast.capsule(context, t('export.noData', ref.read(localeCodeProvider)), Colors.orange);
      setState(() => _isExporting = false);
      return;
    }

    // 保存到可访问的位置
    try {
      final loc = ref.read(localeCodeProvider);
      if (Platform.isWindows) {
        await CsvExporter.exportToDesktop(items, locale: loc);
        if (mounted) AppToast.capsule(context, t('export.toDesktop', ref.read(localeCodeProvider)), Colors.green);
      } else {
        final path = await CsvExporter.exportToDownloads(items, locale: loc);
        final fileName = path.split(Platform.pathSeparator).last;
        if (mounted) AppToast.capsule(context, t('export.toDownloads', ref.read(localeCodeProvider)).replaceAll('{name}', fileName), Colors.green);
      }
    } catch (e) {
      if (mounted) AppToast.capsule(context, '${t('export.failed', ref.read(localeCodeProvider))}: $e', Colors.red);
    }

    if (mounted) setState(() => _isExporting = false);
  }
}
