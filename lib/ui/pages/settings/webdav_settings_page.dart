import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/translations.dart';
import '../../../data/database/config_dao.dart';
import '../../../data/database/database_manager.dart';
import '../../../data/models/asset_item.dart';
import '../../../services/webdav_service.dart';
import '../../providers/asset_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_toast.dart';

/// WebDAV 远程备份设置页面
class WebdavSettingsPage extends ConsumerStatefulWidget {
  const WebdavSettingsPage({super.key});

  @override
  ConsumerState<WebdavSettingsPage> createState() => _WebdavSettingsPageState();
}

class _WebdavSettingsPageState extends ConsumerState<WebdavSettingsPage> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pathController = TextEditingController();
  bool _autoBackup = false;
  int _backupIntervalDays = 7;
  bool _isTesting = false;
  bool _isBackingUp = false;

  final ConfigDao _configDao = ConfigDao();
  final WebDavService _webdavService = WebDavService();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await _configDao.getConfig();
    _urlController.text = config.webdavUrl;
    _usernameController.text = config.webdavUsername;
    _passwordController.text = config.webdavPassword;
    _pathController.text = config.webdavPath;
    _autoBackup = config.autoBackup;
    _backupIntervalDays = config.backupIntervalDays;
    setState(() {});
  }

  Future<void> _save() async {
    final existing = await _configDao.getConfig();
    final config = existing.copyWith(
      webdavUrl: _urlController.text.trim(),
      webdavUsername: _usernameController.text.trim(),
      webdavPassword: _passwordController.text.trim(),
      webdavPath: _pathController.text.trim().isEmpty
          ? '/AssetKeeper'
          : _pathController.text.trim(),
      autoBackup: _autoBackup,
      backupIntervalDays: _backupIntervalDays,
    );
    await _configDao.saveConfig(config);
    ref.invalidate(configProvider);
    if (mounted) {
      AppToast.capsule(context, t('toast.saved', ref.read(localeCodeProvider)), Colors.green);
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    AppToast.loading(context, t('webdav.testLoading', ref.read(localeCodeProvider)));
    await _save();

    final error = await _webdavService.testConnection();
    if (mounted) {
      AppToast.dismiss(context);
    }
    setState(() => _isTesting = false);

    if (!mounted) return;
    AppToast.bottom(
      context,
      error == null ? t('webdav.connected', ref.read(localeCodeProvider)) : '❌ $error',
      error == null ? Colors.green : Colors.red,
      seconds: error == null ? 3 : 5,
    );
  }

  Future<void> _backupNow() async {
    setState(() => _isBackingUp = true);
    await _save();

    final result = await _webdavService.uploadBackup();
    setState(() => _isBackingUp = false);

    if (!mounted) return;
    if (result['success'] == true) {
      AppToast.capsule(context, t('toast.saved', ref.read(localeCodeProvider)), Colors.green);
    } else {
      AppToast.bottom(context, '❌ ${t('backup.title', ref.read(localeCodeProvider))}: ${result['error']}', Colors.red, seconds: 5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc2 = ref.read(localeCodeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(t('webdav.title', loc2)),
        actions: [
          TextButton(onPressed: _save, child: Text(t('ai.save', loc2))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: t('webdav.url', loc2),
                      hintText: 'https://dav.jianguoyun.com/dav',
                      prefixIcon: const Icon(Icons.cloud),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: t('webdav.username', loc2),
                      hintText: 'your@email.com',
                      prefixIcon: const Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: t('webdav.password', loc2),
                      hintText: t('webdav.password', loc2),
                      prefixIcon: const Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pathController,
                    decoration: InputDecoration(
                      labelText: t('webdav.path', loc2),
                      hintText: '/AssetKeeper',
                      prefixIcon: const Icon(Icons.folder),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(t('webdav.autoBackup', loc2)),
                    subtitle: Text('${t('webdav.interval', loc2)} $_backupIntervalDays'),
                    value: _autoBackup,
                    onChanged: (v) => setState(() => _autoBackup = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_autoBackup)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Text(t('webdav.intervalLabel', ref.read(localeCodeProvider))),
                          const Spacer(),
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              initialValue: _backupIntervalDays.toString(),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onChanged: (v) {
                                final days = int.tryParse(v) ?? 7;
                                setState(() => _backupIntervalDays = days.clamp(1, 90));
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTesting ? null : _testConnection,
                          icon: _isTesting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.wifi_tethering),
                          label: Text(_isTesting ? t('webdav.testing', loc2) : t('webdav.test', loc2)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isBackingUp ? null : _backupNow,
                          icon: _isBackingUp
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.cloud_upload),
                          label: Text(_isBackingUp ? t('webdav.backingUp', loc2) : t('webdav.backupNow', loc2)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 查看远程备份按钮
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showBackupListDialog,
              icon: const Icon(Icons.cloud_download),
              label: Text(t('webdav.listBackups', loc2)),
            ),
          ),
        ],
      ),
    );
  }

  /// 弹出远程备份文件列表对话框
  Future<void> _showBackupListDialog() async {
    // 先显示加载
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final backups = await _webdavService.listBackups();
      if (!mounted) return;
      Navigator.pop(context); // 关加载

      if (backups.isEmpty) {
        final loc = ref.read(localeCodeProvider);
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            title: Text(t('webdav.remoteBackupTitle', loc)),
            content: Text(t('webdav.noRemoteBackup', loc)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('confirm.cancel', loc)),
              ),
            ],
          ),
        );
        return;
      }

      final loc = ref.read(localeCodeProvider);
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          title: Text(t('webdav.remoteBackupFiles', loc)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (_, i) {
                final file = backups[i];
                return ListTile(
                  leading: const Icon(Icons.backup, color: Colors.teal),
                  title: Text(
                    file['fileName'] ?? '',
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    '${_formatSize(file['fileSize'] ?? 0)} · ${file['lastModified'] ?? ''}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmRestore(file['fileName'] ?? '');
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('confirm.cancel', loc)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 关加载
      final loc = ref.read(localeCodeProvider);
      final msg = e.toString().replaceAll('Exception: ', '');
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          title: Text(t('webdav.connectionFailed', loc)),
          content: Text(_translateWebdavError(msg, loc)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('confirm.close', loc)),
            ),
          ],
        ),
      );
    }
  }

  /// 第一次确认：选择恢复方式
  Future<void> _confirmRestore(String fileName) async {
    final mode = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(t('restore.title', ref.read(localeCodeProvider))),
        content: Text(t('restore.content', ref.read(localeCodeProvider)).replaceAll('{name}', fileName).replaceAll('{n}', '?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('confirm.cancel', ref.read(localeCodeProvider))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            child: Text(t('restore.replace', ref.read(localeCodeProvider))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'merge'),
            child: Text(t('restore.merge', ref.read(localeCodeProvider))),
          ),
        ],
      ),
    );
    if (mode == null) return;
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(t('restore.confirmTitle', ref.read(localeCodeProvider))),
        content: Text(
          mode == 'replace'
              ? t('restore.confirmReplace', ref.read(localeCodeProvider))
              : t('restore.confirmMerge', ref.read(localeCodeProvider)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('confirm.cancel', ref.read(localeCodeProvider))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t('restore.confirmButton', ref.read(localeCodeProvider))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _doRestore(fileName, mode);
  }

  /// 执行恢复
  Future<void> _doRestore(String fileName, String mode) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    final downloadResult = await _webdavService.downloadBackup(fileName);
    if (downloadResult['success'] != true) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        AppToast.bottom(context, '${t('backup.failed', ref.read(localeCodeProvider))}: ${downloadResult['error']}', Colors.red);
      }
      return;
    }

    final localPath = downloadResult['localPath'] as String;
    final file = File(localPath);
    if (!await file.exists()) {
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      final remoteItems = jsonList
          .map((e) => AssetItem.fromJson(e as Map<String, dynamic>))
          .toList();

      final db = DatabaseManager.instance;
      if (mode == 'replace') {
        await db.replaceAll(remoteItems);
      } else {
        await db.mergeDeduplicated(remoteItems);
      }
      // 刷新 UI
      ref.bumpVersion();

      if (mounted) Navigator.pop(context);
      if (mounted) {
        AppToast.capsule(context, t('restore.success', ref.read(localeCodeProvider)).replaceAll('{n}', '${remoteItems.length}'), Colors.green);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        AppToast.bottom(context, '${t('restore.failed', ref.read(localeCodeProvider))}: $e', Colors.red);
      }
    }
  }

  String _translateWebdavError(String msg, String locale) {
    if (msg.startsWith('webdav.err')) {
      final parts = msg.split(':');
      final key = parts[0];
      if (parts.length > 1) {
        return t(key, locale)
            .replaceAll('{url}', parts[1])
            .replaceAll('{code}', parts[1])
            .replaceAll('{total}', parts[1])
            .replaceAll('{dirs}', parts.length > 2 ? parts[2] : '0')
            .replaceAll('{props}', parts.length > 3 ? parts[3] : '0');
      }
      return t(key, locale);
    }
    return msg;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
