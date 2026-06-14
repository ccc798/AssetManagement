import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/app_info_service.dart';
import 'core/services/version_service.dart';
import 'data/database/database_manager.dart';
import 'services/backup_scheduler.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await AppInfoService.init();

  await VersionService.cleanupOldApksOnStart();

  await DatabaseManager.instance.init();

  await NotificationService.instance.initialize();

  BackupScheduler.instance.start();

  runApp(
    const ProviderScope(
      child: AssetManagementApp(),
    ),
  );
}