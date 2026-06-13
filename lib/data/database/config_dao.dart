import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/backup_config.dart';

/// 配置数据访问 — 单例
///
/// 所有 `ConfigDao()` 获得同一实例，共享缓存，避免页面保存后服务层读到空值。
class ConfigDao {
  // ---- 单例 ----
  static final ConfigDao _instance = ConfigDao._internal();
  factory ConfigDao() => _instance;
  ConfigDao._internal();

  BackupConfig? _cached;
  String? _filePath;

  Future<String> get _path async {
    if (_filePath != null) return _filePath!;
    final dir = await getApplicationDocumentsDirectory();
    _filePath = '${dir.path}/asset_management_config.json';
    return _filePath!;
  }

  Future<BackupConfig> getConfig() async {
    if (_cached != null) return _cached!;
    try {
      final file = File(await _path);
      if (await file.exists()) {
        final content = await file.readAsString();
        _cached = BackupConfig.fromJson(
          jsonDecode(content) as Map<String, dynamic>,
        );
        return _cached!;
      }
    } catch (_) {}
    _cached = BackupConfig.default_;
    return _cached!;
  }

  Future<BackupConfig> saveConfig(BackupConfig config) async {
    _cached = config;
    final file = File(await _path);
    await file.writeAsString(jsonEncode(config.toJson()));
    return config;
  }

  Future<void> updateLastBackupTime(DateTime time) async {
    final config = await getConfig();
    await saveConfig(config.copyWith(lastBackupAt: time));
  }

  /// 获取主题配置
  Future<Map<String, dynamic>> getThemeConfig() async {
    final config = await getConfig();
    return {'themeMode': config.themeMode, 'colorSeed': config.colorSeed};
  }

  /// 设置明暗模式
  Future<void> setThemeMode(String mode) async {
    final config = await getConfig();
    await saveConfig(config.copyWith(themeMode: mode));
  }

  /// 设置主题色种子
  Future<void> setColorSeed(int seed) async {
    final config = await getConfig();
    await saveConfig(config.copyWith(colorSeed: seed));
  }

  Future<bool> needsBackup() async {
    final config = await getConfig();
    if (!config.autoBackup) return false;
    if (config.lastBackupAt == null) return true;
    return DateTime.now().difference(config.lastBackupAt!).inDays >=
        config.backupIntervalDays;
  }
}
