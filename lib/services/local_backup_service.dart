import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../data/models/asset_item.dart';
import '../core/utils/csv_export.dart';

/// 本地备份/恢复服务 — 独立模块
///
/// 职责：
/// - 本地备份：将数据库 JSON 复制到系统下载文件夹
/// - 本地恢复：读取用户选择的备份文件，返回物品列表
///
/// 所有异常向上抛，由 UI 层捕获并显示友好提示。
class LocalBackupService {
  LocalBackupService._();

  /// 备份：将当前数据库 JSON 复制到下载文件夹
  ///
  /// 返回保存的文件路径
  /// 失败抛异常，异常消息为中文友好提示
  static Future<String> backupToDownloads() async {
    // 1. 获取数据库文件路径
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File('${dir.path}/asset_management_data.json');

    if (!await dbFile.exists()) {
      throw Exception('数据库文件不存在，请先添加物品');
    }

    // 2. 读取数据库内容
    final content = await dbFile.readAsString();

    // 3. 验证 JSON 有效性
    try {
      final parsed = jsonDecode(content);
      if (parsed is! List) {
        throw Exception('数据库格式异常，无法备份');
      }
    } catch (_) {
      throw Exception('数据库文件损坏，无法备份');
    }

    // 4. 获取公开下载目录
    final targetDir = await getPublicDownloadsPath();

    // 5. 写入备份文件
    final now = DateTime.now();
    final pad = (int n) => n.toString().padLeft(2, '0');
    final fileName = 'AssetManagement_Backup_${now.year}-${pad(now.month)}-${pad(now.day)}_${pad(now.hour)}${pad(now.minute)}${pad(now.second)}.json';
    final targetFile = File('$targetDir/$fileName');

    try {
      await targetFile.writeAsString(content, flush: true);
    } catch (e) {
      throw Exception('文件写入失败，${e.toString().contains('denied') ? '无写入权限' : e.toString().replaceAll('Exception: ', '')}');
    }

    if (!await targetFile.exists()) {
      throw Exception('文件保存失败，请检查存储空间');
    }

    return targetFile.path;
  }

  /// 恢复：读取备份文件，返回物品列表
  ///
  /// [filePath] 用户选择的文件路径
  /// 返回解析后的物品列表
  /// 失败抛异常，异常消息为中文友好提示
  static Future<List<AssetItem>> restoreFromFile(String filePath) async {
    // 1. 检查文件是否存在
    final file = File(filePath);

    if (!await file.exists()) {
      throw Exception('文件不存在，请重新选择');
    }

    // 2. 检查文件大小
    try {
      final stat = await file.stat();
      if (stat.size == 0) {
        throw Exception('文件为空，不是有效的备份文件');
      }
      if (stat.size > 50 * 1024 * 1024) {
        throw Exception('文件过大（超过50MB），无法恢复');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('无法读取文件信息，请确认文件可访问');
    }

    // 3. 读取文件内容
    String content;
    try {
      content = await file.readAsString();
    } catch (e) {
      throw Exception('文件读取失败，${e.toString().contains('denied') ? '无读取权限' : '请确认文件未被占用'}');
    }

    if (content.trim().isEmpty) {
      throw Exception('文件内容为空，不是有效的备份文件');
    }

    // 4. 解析 JSON
    List<dynamic> jsonList;
    try {
      final parsed = jsonDecode(content);
      if (parsed is! List) {
        throw Exception('文件格式不正确，不是 Asset Management 备份文件（期望 JSON 数组）');
      }
      jsonList = parsed;
    } on FormatException {
      throw Exception('文件格式不正确，不是有效的 JSON 备份文件');
    } catch (_) {
      throw Exception('文件格式不正确，无法解析');
    }

    if (jsonList.isEmpty) {
      throw Exception('备份文件中没有数据');
    }

    // 5. 逐条验证并转换
    final items = <AssetItem>[];
    for (int i = 0; i < jsonList.length; i++) {
      final item = jsonList[i];
      if (item is! Map<String, dynamic>) {
        throw Exception('第${i + 1} 条数据格式不正确，不是有效的物品数据');
      }
      try {
        items.add(AssetItem.fromJson(item));
      } catch (e) {
        throw Exception('第${i + 1} 条数据解析失败，${e.toString().replaceAll('Exception: ', '').replaceAll('FormatException: ', '')}');
      }
    }

    return items;
  }
}
