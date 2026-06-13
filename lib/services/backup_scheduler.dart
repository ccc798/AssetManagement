import 'dart:async';
import '../data/database/config_dao.dart';
import '../services/webdav_service.dart';

/// 自动备份调度器
///
/// 在 app 启动和从后台恢复时检查是否需要自动备份。
/// 需要备份时静默执行，失败时静默忽略（不打扰用户）。
class BackupScheduler {
  BackupScheduler._();
  static final BackupScheduler instance = BackupScheduler._();

  final ConfigDao _configDao = ConfigDao();
  final WebDavService _webdavService = WebDavService();
  bool _started = false;

  /// 启动调度器（在 app 初始化后调用）
  void start() {
    if (_started) return;
    _started = true;
    _checkAndBackup();
  }

  /// 检查并执行备份（静默）
  Future<void> _checkAndBackup() async {
    try {
      // 1. 检查配置
      final config = await _configDao.getConfig();
      if (!config.autoBackup || config.webdavUrl.isEmpty) return;

      // 2. 检查是否需要备份
      final needsBackup = await _configDao.needsBackup();
      if (!needsBackup) return;

      // 3. 执行备份
      final result = await _webdavService.uploadBackup();

      // 4. 成功不需要通知，失败也静默
      if (result['success'] == true) {
        // lastBackupAt 已在 uploadBackup 中更新
      }
    } catch (_) {
      // 静默失败
    }
  }
}
