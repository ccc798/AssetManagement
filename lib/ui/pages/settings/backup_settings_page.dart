import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/i18n/translations.dart';
import '../../../data/database/database_manager.dart';
import '../../../data/models/asset_item.dart';
import '../../../services/local_backup_service.dart';
import '../../providers/asset_provider.dart';
import '../../widgets/app_toast.dart';
import 'webdav_settings_page.dart';

/// 备份与恢复页面
class BackupSettingsPage extends ConsumerWidget {
  const BackupSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loc2 = ref.read(localeCodeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t('backup.title', loc2))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle(t('backup.local', loc2), theme),
          const SizedBox(height: 8),
          _buildLocalBackupCard(context, ref, loc2),
          const SizedBox(height: 24),
          _buildSectionTitle(t('backup.remote', loc2), theme),
          const SizedBox(height: 8),
          _buildWebdavCard(context, ref, loc2),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text, ThemeData theme) {
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildLocalBackupCard(BuildContext context, WidgetRef ref, String loc2) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildIconContainer(Colors.teal, Icons.computer),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    t('backup.localDesc', loc2),
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _localBackup(context, ref),
                    icon: const Icon(Icons.download),
                    label: Text(t('backup.localBackup', loc2)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _localRestore(context, ref, loc2),
                    icon: const Icon(Icons.upload),
                    label: Text(t('backup.localRestore', loc2)),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.teal),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebdavCard(BuildContext context, WidgetRef ref, String loc2) {
    return Card(
      child: ListTile(
        leading: _buildIconContainer(Colors.blue, Icons.cloud_upload),
        title: Text(t('webdav.title', loc2)),
        subtitle: Text(t('backup.webdavSub', loc2)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WebdavSettingsPage()),
        ),
      ),
    );
  }

  Widget _buildIconContainer(Color color, IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color),
    );
  }

  void _dismissAndShowError(BuildContext context, String message) {
    AppToast.dismiss(context);
    if (context.mounted) {
      AppToast.bottom(context, message, Colors.red, seconds: 5);
    }
  }

  void _dismissAndShowSuccess(BuildContext context, String message) {
    AppToast.dismiss(context);
    if (context.mounted) {
      AppToast.capsule(context, message, Colors.green);
    }
  }

  Future<void> _localBackup(BuildContext context, WidgetRef ref) async {
    final loc = ref.read(localeCodeProvider);
    AppToast.loading(context, t('backup.backingUp', loc));

    try {
      final path = await LocalBackupService.backupToDownloads();
      final fileName = path.split(Platform.pathSeparator).last;
      _dismissAndShowSuccess(
        context,
        t('backup.savedToDownloads', loc).replaceAll('{name}', fileName),
      );
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      _dismissAndShowError(
        context,
        '${t('backup.failed', loc)}: $msg',
      );
    }
  }

  Future<void> _localRestore(BuildContext context, WidgetRef ref, String loc2) async {
    AppToast.loading(context, t('backup.openingFilePicker', loc2));

    try {
      final result = await FilePicker.pickFiles(type: FileType.any, allowMultiple: false);
      AppToast.dismiss(context);

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) {
        if (context.mounted) {
          AppToast.bottom(context, '❌ ${t('backup.restoreFailedFile', loc2)}', Colors.red);
        }
        return;
      }

      final remoteItems = await _parseBackupFile(context, filePath, loc2);
      if (remoteItems == null) return;

      final mode = await _selectRestoreMode(context, loc2, result.files.single.name, remoteItems.length);
      if (mode == null) return;

      if (!await _confirmRestore(context, loc2, mode)) return;

      await _executeRestore(context, ref, loc2, mode, remoteItems);
    } catch (e) {
      _dismissAndShowError(
        context,
        '${t('backup.failed', loc2)}: ${_translateError(e.toString().replaceAll('Exception: ', ''), loc2)}',
      );
    }
  }

  Future<List<AssetItem>?> _parseBackupFile(BuildContext context, String filePath, String loc2) async {
    try {
      return await LocalBackupService.restoreFromFile(filePath);
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      _dismissAndShowError(context, '❌ ${t('restore.failed', loc2)}: ${_translateError(msg, loc2)}');
      return null;
    }
  }

  Future<String?> _selectRestoreMode(
    BuildContext context,
    String loc2,
    String fileName,
    int itemCount,
  ) async {
    if (!context.mounted) return null;

    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(t('restore.title', loc2)),
        content: Text(
          t('restore.content', loc2)
              .replaceAll('{name}', fileName)
              .replaceAll('{n}', itemCount.toString()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('confirm.cancel', loc2))),
          TextButton(onPressed: () => Navigator.pop(ctx, 'replace'), child: Text(t('restore.replace', loc2))),
          TextButton(onPressed: () => Navigator.pop(ctx, 'merge'), child: Text(t('restore.merge', loc2))),
        ],
      ),
    );
  }

  Future<bool> _confirmRestore(BuildContext context, String loc2, String mode) async {
    if (!context.mounted) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(t('restore.confirmTitle', loc2)),
        content: Text(mode == 'replace' ? t('restore.confirmReplace', loc2) : t('restore.confirmMerge', loc2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('confirm.cancel', loc2))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t('restore.confirmButton', loc2)),
          ),
        ],
      ),
    );

    return confirmed == true && context.mounted;
  }

  Future<void> _executeRestore(
    BuildContext context,
    WidgetRef ref,
    String loc2,
    String mode,
    List<AssetItem> remoteItems,
  ) async {
    final loc = ref.read(localeCodeProvider);
    AppToast.loading(context, t('backup.restoring', loc).replaceAll('{n}', remoteItems.length.toString()));

    try {
      final db = DatabaseManager.instance;
      if (mode == 'replace') {
        await db.replaceAll(remoteItems);
      } else {
        await db.mergeDeduplicated(remoteItems);
      }
      ref.bumpVersion();
      _dismissAndShowSuccess(
        context,
        t('backup.restored', loc).replaceAll('{n}', remoteItems.length.toString()),
      );
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      _dismissAndShowError(
        context,
        '${t('backup.failed', loc)}: ${_translateError(msg, loc)}',
      );
    }
  }
}

String _translateError(String msg, String locale) {
  if (msg.startsWith('backup.err')) {
    final parts = msg.split(':');
    final key = parts[0];
    if (parts.length > 1) {
      return t(key, locale).replaceAll('{i}', parts[1]);
    }
    return t(key, locale);
  }
  if (msg.startsWith('webdav.err')) {
    final parts = msg.split(':');
    final key = parts[0];
    if (parts.length > 1) {
      return t(key, locale).replaceAll('{url}', parts[1]).replaceAll('{code}', parts[1]);
    }
    return t(key, locale);
  }
  if (msg.startsWith('category.err')) {
    return t(msg, locale);
  }
  return msg;
}
