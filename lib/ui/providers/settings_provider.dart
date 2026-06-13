import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/config_dao.dart';
import '../../data/models/backup_config.dart';

final configDaoProvider = Provider<ConfigDao>((ref) => ConfigDao());

/// 配置 provider
final configProvider = FutureProvider<BackupConfig>((ref) async {
  final dao = ref.read(configDaoProvider);
  return dao.getConfig();
});
