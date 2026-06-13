import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'data/database/database_manager.dart';
import 'services/backup_scheduler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置状态栏
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 初始化数据库
  await DatabaseManager.instance.init();

  // 启动自动备份调度（启动时检查一次）
  BackupScheduler.instance.start();

  runApp(
    const ProviderScope(
      child: AssetManagementApp(),
    ),
  );
}
