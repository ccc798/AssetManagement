import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/translations.dart';
import '../../../core/utils/csv_export.dart';
import '../../../core/utils/csv_import.dart';
import '../../../data/models/asset_item.dart';
import '../../../services/local_backup_service.dart';
import '../../providers/asset_provider.dart';
import '../../providers/category_provider.dart';
import '../../widgets/app_toast.dart';

class DataManagementPage extends ConsumerStatefulWidget {
  const DataManagementPage({super.key});

  @override
  ConsumerState<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends ConsumerState<DataManagementPage> {
  String _scope = 'active';
  bool _isExporting = false;
  bool _isImporting = false;
  String? _selectedFilePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = ref.read(localeCodeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t('dataManagement.title', loc))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildExportSection(theme, loc),
          const SizedBox(height: 24),
          _buildImportSection(theme, loc),
        ],
      ),
    );
  }

  Widget _buildExportSection(ThemeData theme, String loc) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.file_download, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  t('dataManagement.exportSection', loc),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(t('export.scope', loc), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                ChoiceChip(
                  label: Text(t('export.all', loc)),
                  selected: _scope == 'all',
                  onSelected: (_) => setState(() => _scope = 'all'),
                ),
                ChoiceChip(
                  label: Text(t('export.active', loc)),
                  selected: _scope == 'active',
                  onSelected: (_) => setState(() => _scope = 'active'),
                ),
                ChoiceChip(
                  label: Text(t('export.archived', loc)),
                  selected: _scope == 'archived',
                  onSelected: (_) => setState(() => _scope = 'archived'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _doExport,
                icon: _isExporting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.table_chart),
                label: Text(_isExporting ? t('export.exporting', loc) : t('export.button', loc)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _doExportImages,
                icon: _isExporting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.photo_library),
                label: Text(_isExporting ? t('export.exporting', loc) : t('export.images', loc)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSection(ThemeData theme, String loc) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.file_upload, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  t('dataManagement.importSection', loc),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t('dataManagement.templateDesc', loc),
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isImporting ? null : _downloadTemplate,
                icon: const Icon(Icons.description),
                label: Text(t('dataManagement.template', loc)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_selectedFilePath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.attach_file, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedFilePath!.split(Platform.pathSeparator).last,
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _selectedFilePath = null),
                    ),
                  ],
                ),
              ),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isImporting ? null : _selectFile,
                icon: const Icon(Icons.folder_open),
                label: Text(t('dataManagement.selectFile', loc)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_isImporting || _selectedFilePath == null) ? null : _doImport,
                icon: _isImporting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_file),
                label: Text(_isImporting ? t('dataManagement.importing', loc) : t('dataManagement.import', loc)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
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

  Future<void> _doExportImages() async {
    setState(() => _isExporting = true);

    try {
      final dao = ref.read(assetDaoProvider);
      final items = await dao.getAll();

      if (items.isEmpty) {
        if (mounted) AppToast.capsule(context, t('export.noData', ref.read(localeCodeProvider)), Colors.orange);
        setState(() => _isExporting = false);
        return;
      }

      final count = await LocalBackupService.exportImagesToDownloads(items);
      if (mounted) {
        if (count > 0) {
          AppToast.capsule(context, t('export.imagesExported', ref.read(localeCodeProvider)).replaceAll('{n}', '$count'), Colors.green);
        } else {
          AppToast.capsule(context, t('export.noImages', ref.read(localeCodeProvider)), Colors.orange);
        }
      }
    } catch (e) {
      if (mounted) AppToast.capsule(context, '${t('export.failed', ref.read(localeCodeProvider))}: $e', Colors.red);
    }

    if (mounted) setState(() => _isExporting = false);
  }

  Future<void> _downloadTemplate() async {
    try {
      final loc = ref.read(localeCodeProvider);
      await CsvImporter.downloadTemplate(locale: loc);
      if (mounted) {
        AppToast.capsule(context, t('dataManagement.templateSuccess', loc), Colors.green);
      }
    } catch (e) {
      if (mounted) {
        AppToast.capsule(context, '${t('export.failed', ref.read(localeCodeProvider))}: $e', Colors.red);
      }
    }
  }

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          setState(() => _selectedFilePath = file.path);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.capsule(context, '${t('dataManagement.invalidFile', ref.read(localeCodeProvider))}: $e', Colors.red);
      }
    }
  }

  Future<void> _doImport() async {
    if (_selectedFilePath == null) return;

    setState(() => _isImporting = true);

    try {
      final loc = ref.read(localeCodeProvider);
      final categoriesAsync = ref.read(categoryListProvider);
      final List<String> validCategories = categoriesAsync.when(
        data: (cats) => cats.map((c) => c.name).toList(),
        loading: () => <String>[],
        error: (_, __) => <String>[],
      );

      final result = await CsvImporter.parseAndValidate(
        _selectedFilePath!,
        validCategories,
        locale: loc,
      );

      if (result.hasErrors) {
        await _showErrorDialog(result, loc);
      } else {
        await _saveImportedItems(result.validItems, loc);
      }
    } catch (e) {
      if (mounted) {
        AppToast.capsule(context, '${t('dataManagement.importFailed', ref.read(localeCodeProvider))}: $e', Colors.red);
      }
    }

    if (mounted) setState(() => _isImporting = false);
  }

  Future<void> _showErrorDialog(ImportResult result, String loc) async {
    final theme = Theme.of(context);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('import.errorTitle', loc)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            children: [
              Text(
                t('dataManagement.importPartial', loc)
                    .replaceAll('{success}', '${result.successCount}')
                    .replaceAll('{failed}', '${result.errorCount}'),
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.orange),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: result.errors.length,
                  itemBuilder: (ctx, index) {
                    final error = result.errors[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      title: Text(error.toDisplayString(loc), style: const TextStyle(fontSize: 13)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('dataManagement.cancelImport', loc)),
          ),
          if (result.validItems.isNotEmpty)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _saveImportedItems(result.validItems, loc);
              },
              child: Text(t('dataManagement.skipErrors', loc)),
            ),
        ],
      ),
    );
  }

  Future<void> _saveImportedItems(List<AssetItem> items, String loc) async {
    final dao = ref.read(assetDaoProvider);
    int savedCount = 0;

    for (final item in items) {
      try {
        await dao.add(item);
        savedCount++;
      } catch (_) {}
    }

    ref.bumpVersion();

    if (mounted) {
      AppToast.capsule(
        context,
        t('dataManagement.importSuccess', loc).replaceAll('{n}', '$savedCount'),
        Colors.green,
      );
      setState(() => _selectedFilePath = null);
    }
  }
}