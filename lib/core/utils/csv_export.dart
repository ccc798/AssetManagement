import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../data/models/asset_item.dart';
import '../i18n/translations.dart';

/// 获取系统公开下载目录（Android /storage/emulated/0/Download，其他平台用 getDownloadsDirectory）
Future<String> getPublicDownloadsPath() async {
  if (Platform.isAndroid) {
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        // /storage/emulated/0/Android/data/<pkg>/files → /storage/emulated/0/Download
        final parts = extDir.path.split(Platform.pathSeparator);
        final basePath = parts.take(4).join(Platform.pathSeparator);
        final downloadDir = Directory('$basePath/Download');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        return downloadDir.path;
      }
    } catch (_) {}
  }
  final dir = await getDownloadsDirectory();
  return dir?.path ?? (await getApplicationDocumentsDirectory()).path;
}

/// CSV 导出工具
class CsvExporter {
  CsvExporter._();

  /// 保存 CSV 到系统公开下载目录
  static Future<String> exportToDownloads(List<AssetItem> items, {String locale = 'zh'}) async {
    final csv = _buildCsv(items, locale: locale);
    final dir = await getPublicDownloadsPath();
    final fileName = 'Assets_${_formatDate(DateTime.now())}.csv';
    final file = File('$dir/$fileName');
    await file.writeAsBytes(csv, flush: true);
    return file.path;
  }

  /// Windows 桌面直接保存
  static Future<String> exportToDesktop(List<AssetItem> items, {String locale = 'zh'}) async {
    final csv = _buildCsv(items, locale: locale);
    final home = Platform.environment['USERPROFILE'] ?? '';
    final dir = Directory('$home\\Desktop');
    if (!await dir.exists()) dir.createSync(recursive: true);
    final fileName = 'Assets_${_formatDate(DateTime.now())}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(csv, flush: true);
    return file.path;
  }

  /// 生成 UTF-8 BOM CSV 字节数据，表头按 locale 翻译
  static List<int> _buildCsv(List<AssetItem> items, {String locale = 'zh'}) {
    final buf = StringBuffer();

    // UTF-8 BOM
    buf.write('\uFEFF');

    // 表头（按语言翻译）
    final headers = [
      t('csv.name', locale), t('csv.category', locale), t('csv.brand', locale),
      t('csv.price', locale), t('csv.purchaseDate', locale),
      t('csv.daysUsed', locale), t('csv.dailyCost', locale), t('csv.remainingValue', locale),
      t('csv.plannedLifetime', locale),
      t('csv.rating', locale), t('csv.tags', locale), t('csv.notes', locale),
      t('csv.status', locale),
      t('csv.warranty', locale), t('csv.warrantyExpiry', locale), t('csv.insurance', locale),
    ];
    buf.writeln(headers.map(_escapeCsvField).join(','));

    // 数据行
    for (final item in items) {
      final status = item.isDeleted ? t('csv.deleted', locale)
          : item.isArchived ? t('csv.archived', locale) : t('csv.active', locale);
      final row = [
        item.name,
        item.category,
        item.brand,
        item.price.toStringAsFixed(2),
        item.purchaseDate != null
            ? '${item.purchaseDate!.year}-${_pad(item.purchaseDate!.month)}-${_pad(item.purchaseDate!.day)}'
            : '',
        item.daysUsed.toString(),
        item.dailyCost.toStringAsFixed(4),
        '${(item.remainingValueRatio * 100).toStringAsFixed(1)}%',
        item.plannedLifetimeDays.toString(),
        item.rating.toString(),
        item.tags.join('; '),
        item.notes,
        status,
        item.warrantyPeriod ?? '',
        item.warrantyExpiry != null
            ? '${item.warrantyExpiry!.year}-${_pad(item.warrantyExpiry!.month)}-${_pad(item.warrantyExpiry!.day)}'
            : '',
        item.insuranceInfo ?? '',
      ];
      buf.writeln(row.map(_escapeCsvField).join(','));
    }

    return utf8.encode(buf.toString());
  }

  /// CSV 字段转义（逗号/引号/换行）
  static String _escapeCsvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// 月份/日期补零
  static String _pad(int n) => n.toString().padLeft(2, '0');

  /// 格式化日期为 yyyy-MM-dd
  static String _formatDate(DateTime dt) {
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';
  }
}
