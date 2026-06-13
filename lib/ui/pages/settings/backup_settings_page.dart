import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/translations.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/database/database_manager.dart';
import '../../../data/models/asset_item.dart';
import '../../../services/local_backup_service.dart';
import '../../../services/webdav_service.dart';
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
          // ─── 本地备份与恢复 ───
          Text(t('backup.local', loc2), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.computer, color: Colors.teal),
                      ),
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
          ),
          const SizedBox(height: 24),

          // ─── WebDAV 远程备份 ───
          Text(t('backup.remote', loc2), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_upload, color: Colors.blue),
              ),
              title: Text(t('webdav.title', loc2)),
              subtitle: Text(t('backup.webdavSub', loc2)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WebdavSettingsPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ─── 本地备份 ───
  Future<void> _localBackup(BuildContext context, WidgetRef ref) async {
    AppToast.loading(context, t('backup.backingUp', ref.read(localeCodeProvider)));
    try {
      final path = await LocalBackupService.backupToDownloads();
      AppToast.dismiss(context);
      final fileName = path.split(Platform.pathSeparator).last;
      if (context.mounted) {
        AppToast.capsule(context, t('backup.savedToDownloads', ref.read(localeCodeProvider)).replaceAll('{name}', fileName), Colors.green);
      }
    } catch (e) {
      AppToast.dismiss(context);
      final msg = e.toString().replaceAll('Exception: ', '');
      if (context.mounted) {
        AppToast.bottom(context, '${t('backup.failed', ref.read(localeCodeProvider))}: $msg', Colors.red, seconds: 5);
      }
    }
  }

  /// ─── 本地恢复 ───
  Future<void> _localRestore(BuildContext context, WidgetRef ref, String loc2) async {
    // 1. 文件选择
    AppToast.loading(context, '正在打开文件选择器...');
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      AppToast.dismiss(context);

      if (result == null || result.files.isEmpty) return; // 用户取消

      final filePath = result.files.single.path;
      if (filePath == null) {
        if (context.mounted) {
          AppToast.bottom(context, '❌ 恢复失败: 无法获取文件路径', Colors.red);
        }
        return;
      }

      // 2. 解析备份文件
      List<AssetItem> remoteItems;
      try {
        remoteItems = await LocalBackupService.restoreFromFile(filePath);
      } catch (e) {
        final msg = e.toString().replaceAll('Exception: ', '');
        if (context.mounted) {
          AppToast.bottom(context, '❌ 恢复失败: $msg', Colors.red, seconds: 5);
        }
        return;
      }

      // 3. 选择恢复模式
      final fileName = result.files.single.name;
      if (!context.mounted) return;
      final mode = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          title: Text(t('restore.title', loc2)),
          content: Text(t('restore.content', loc2).replaceAll('{name}', fileName).replaceAll('{n}', remoteItems.length.toString())),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('confirm.cancel', loc2)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'replace'),
              child: Text(t('restore.replace', loc2)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'merge'),
              child: Text(t('restore.merge', loc2)),
            ),
          ],
        ),
      );
      if (mode == null || !context.mounted) return;

      // 4. 二次确认
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          title: Text(t('restore.confirmTitle', loc2)),
          content: Text(
            mode == 'replace'
                ? t('restore.confirmReplace', loc2)
                : t('restore.confirmMerge', loc2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('confirm.cancel', loc2)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(t('restore.confirmButton', loc2)),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;

      // 5. 执行恢复
      AppToast.loading(context, t('backup.restoring', ref.read(localeCodeProvider)).replaceAll('{n}', '${remoteItems.length}'));
      try {
        final db = DatabaseManager.instance;
        if (mode == 'replace') {
          await db.replaceAll(remoteItems);
        } else {
          await db.mergeDeduplicated(remoteItems);
        }
        ref.bumpVersion();
        AppToast.dismiss(context);
        if (context.mounted) {
          AppToast.capsule(context, t('backup.restored', ref.read(localeCodeProvider)).replaceAll('{n}', '${remoteItems.length}'), Colors.green);
        }
      } catch (e) {
        AppToast.dismiss(context);
        final msg = e.toString().replaceAll('Exception: ', '');
        if (context.mounted) {
          AppToast.bottom(context, '${t('backup.failed', ref.read(localeCodeProvider))}: $msg', Colors.red, seconds: 5);
        }
      }
    } catch (e) {
      AppToast.dismiss(context);
      if (context.mounted) {
        AppToast.bottom(context, '${t('backup.failed', ref.read(localeCodeProvider))}: ${e.toString().replaceAll('Exception: ', '')}', Colors.red, seconds: 5);
      }
    }
  }
}
