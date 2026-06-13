import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../data/models/asset_item.dart';
import '../core/utils/csv_export.dart';

class LocalBackupService {
  LocalBackupService._();

  static Future<String> backupToDownloads() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File('${dir.path}/asset_management_data.json');

    if (!await dbFile.exists()) {
      throw Exception('backup.errNoDataFile');
    }

    final content = await dbFile.readAsString();

    try {
      final parsed = jsonDecode(content);
      if (parsed is! List) {
        throw Exception('backup.errInvalidFormat');
      }
    } catch (_) {
      throw Exception('backup.errCorruptedFile');
    }

    final targetDir = await getPublicDownloadsPath();

    final now = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    final fileName = 'AssetManagement_Backup_${now.year}-${pad(now.month)}-${pad(now.day)}_${pad(now.hour)}${pad(now.minute)}${pad(now.second)}.json';
    final targetFile = File('$targetDir/$fileName');

    try {
      await targetFile.writeAsString(content, flush: true);
    } catch (e) {
      throw Exception('backup.errWriteFailed');
    }

    if (!await targetFile.exists()) {
      throw Exception('backup.errSaveFailed');
    }

    return targetFile.path;
  }

  static Future<List<AssetItem>> restoreFromFile(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw Exception('backup.errFileNotFound');
    }

    try {
      final stat = await file.stat();
      if (stat.size == 0) {
        throw Exception('backup.errEmptyFile');
      }
      if (stat.size > 50 * 1024 * 1024) {
        throw Exception('backup.errFileTooLarge');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('backup.errFileAccess');
    }

    String content;
    try {
      content = await file.readAsString();
    } catch (e) {
      throw Exception('backup.errReadFailed');
    }

    if (content.trim().isEmpty) {
      throw Exception('backup.errEmptyContent');
    }

    List<dynamic> jsonList;
    try {
      final parsed = jsonDecode(content);
      if (parsed is! List) {
        throw Exception('backup.errInvalidJsonArray');
      }
      jsonList = parsed;
    } on FormatException {
      throw Exception('backup.errInvalidJson');
    } catch (_) {
      throw Exception('backup.errInvalidJson');
    }

    if (jsonList.isEmpty) {
      throw Exception('backup.errNoData');
    }

    final items = <AssetItem>[];
    for (int i = 0; i < jsonList.length; i++) {
      final item = jsonList[i];
      if (item is! Map<String, dynamic>) {
        throw Exception('backup.errInvalidItem:${i + 1}');
      }
      try {
        items.add(AssetItem.fromJson(item));
      } catch (e) {
        throw Exception('backup.errParseItem:${i + 1}');
      }
    }

    return items;
  }
}