import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../data/models/asset_item.dart';
import '../constants/app_constants.dart';
import '../i18n/translations.dart';

class ImportError {
  final int row;
  final int col;
  final String type;
  final String message;
  final String fieldName;

  ImportError({
    required this.row,
    required this.col,
    required this.type,
    required this.message,
    required this.fieldName,
  });

  String toDisplayString(String locale) {
    final rowText = t('import.row', locale).replaceAll('{row}', '$row');
    final colText = t('import.col', locale).replaceAll('{col}', '$col');
    return '$rowText, $colText ($fieldName): $message';
  }
}

class ImportResult {
  final List<AssetItem> validItems;
  final List<ImportError> errors;
  final int totalRows;

  ImportResult({
    required this.validItems,
    required this.errors,
    required this.totalRows,
  });

  bool get hasErrors => errors.isNotEmpty;
  int get successCount => validItems.length;
  int get errorCount => errors.length;
}

class CsvImporter {
  CsvImporter._();

  static Future<String> downloadTemplate({String locale = 'zh'}) async {
    final dir = await getPublicDownloadsPath();
    final fileName = 'AssetManagement_Template_$locale.csv';
    final file = File('$dir${Platform.pathSeparator}$fileName');

    final headers = [
      t('csv.name', locale), t('csv.category', locale), t('csv.brand', locale),
      t('csv.price', locale), t('csv.purchaseDate', locale),
      t('csv.daysUsed', locale), t('csv.dailyCost', locale), t('csv.remainingValue', locale),
      t('csv.plannedLifetime', locale),
      t('csv.rating', locale), t('csv.tags', locale), t('csv.notes', locale),
      t('csv.status', locale),
      t('csv.warranty', locale), t('csv.warrantyExpiry', locale), t('csv.insurance', locale),
    ];

    final sampleData1 = locale == 'zh'
        ? ['示例物品1', '电子产品', '品牌A', '999.99', '2024-01-15', '', '', '', '365', '4', '电子;数码', '这是一个示例物品', '使用中', '1年', '2025-01-15', '']
        : ['Sample Item 1', 'Electronics', 'Brand A', '999.99', '2024-01-15', '', '', '', '365', '4', 'digital;tech', 'This is a sample item', 'Active', '1 year', '2025-01-15', ''];

    final sampleData2 = locale == 'zh'
        ? ['示例物品2', '服装鞋帽', '品牌B', '199.00', '2024-02-20', '', '', '', '180', '3', '服装', '另一个示例', '使用中', '', '', '']
        : ['Sample Item 2', 'Clothing', 'Brand B', '199.00', '2024-02-20', '', '', '', '180', '3', 'clothing', 'Another sample', 'Active', '', '', ''];

    final buf = StringBuffer();
    buf.write('\uFEFF');
    buf.writeln(headers.map(_escapeCsvField).join(','));
    buf.writeln(sampleData1.map(_escapeCsvField).join(','));
    buf.writeln(sampleData2.map(_escapeCsvField).join(','));

    await file.writeAsBytes(utf8.encode(buf.toString()), flush: true);
    return file.path;
  }

  static Future<ImportResult> parseAndValidate(
    String filePath,
    List<String> validCategories,
    {String locale = 'zh'}
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return ImportResult(validItems: [], errors: [], totalRows: 0);
    }

    final content = await file.readAsString();
    String csvContent = content;
    if (content.startsWith('\uFEFF')) {
      csvContent = content.substring(1);
    }

    final lines = csvContent.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) {
      return ImportResult(validItems: [], errors: [], totalRows: 0);
    }

    final headerLine = lines[0];
    final headers = _parseCsvLine(headerLine);
    if (headers.length < 5) {
      return ImportResult(
        validItems: [],
        errors: [ImportError(row: 1, col: 0, type: 'format', message: t('import.invalidHeader', locale), fieldName: '')],
        totalRows: 0,
      );
    }

    final validItems = <AssetItem>[];
    final errors = <ImportError>[];
    final categoryMap = _buildCategoryMap(locale);

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final rowNumber = i + 1;
      final fields = _parseCsvLine(line);

      if (fields.length < headers.length) {
        while (fields.length < headers.length) {
          fields.add('');
        }
      }

      final rowErrors = <ImportError>[];
      String? name;
      String? category;
      String brand = '';
      double? price;
      DateTime? purchaseDate;
      int plannedLifetimeDays = 365;
      int rating = 0;
      List<String> tags = [];
      String notes = '';
      bool isArchived = false;
      bool isDeleted = false;
      String? warrantyPeriod;
      DateTime? warrantyExpiry;
      String? insuranceInfo;

      for (int col = 0; col < headers.length && col < 16; col++) {
        final value = fields[col].trim();

        final colNumber = col + 1;
        final fieldName = _getFieldName(col, locale);

        switch (col) {
          case 0:
            if (value.isEmpty) {
              rowErrors.add(ImportError(row: rowNumber, col: colNumber, type: 'empty', message: t('import.nameEmpty', locale), fieldName: fieldName));
            } else {
              name = value;
            }
            break;

          case 1:
            if (value.isEmpty) {
              rowErrors.add(ImportError(row: rowNumber, col: colNumber, type: 'empty', message: t('import.categoryEmpty', locale), fieldName: fieldName));
            } else {
              final resolvedCategory = categoryMap[value.toLowerCase()] ?? value;
              if (!_isValidCategory(resolvedCategory, validCategories)) {
                rowErrors.add(ImportError(row: rowNumber, col: colNumber, type: 'invalid', message: t('import.categoryInvalid', locale), fieldName: fieldName));
              } else {
                category = resolvedCategory;
              }
            }
            break;

          case 2:
            brand = value;
            break;

          case 3:
            if (value.isEmpty) {
              rowErrors.add(ImportError(row: rowNumber, col: colNumber, type: 'empty', message: t('import.priceEmpty', locale), fieldName: fieldName));
            } else {
              final cleanValue = value.replaceAll(',', '').replaceAll('¥', '').replaceAll('\$', '').replaceAll('￥', '');
              final parsed = double.tryParse(cleanValue);
              if (parsed == null) {
                rowErrors.add(ImportError(row: rowNumber, col: colNumber, type: 'type', message: t('import.priceInvalid', locale), fieldName: fieldName));
              } else if (parsed <= 0) {
                rowErrors.add(ImportError(row: rowNumber, col: colNumber, type: 'range', message: t('import.priceNegative', locale), fieldName: fieldName));
              } else {
                price = parsed;
              }
            }
            break;

          case 4:
            if (value.isEmpty) {
              rowErrors.add(ImportError(row: rowNumber, col: colNumber, type: 'empty', message: t('import.dateEmpty', locale), fieldName: fieldName));
            } else {
              final parsed = _parseDate(value);
              if (parsed == null) {
                rowErrors.add(ImportError(row: rowNumber, col: colNumber, type: 'format', message: t('import.dateInvalid', locale), fieldName: fieldName));
              } else {
                purchaseDate = parsed;
              }
            }
            break;

          case 5:
          case 6:
          case 7:
            break;

          case 8:
            if (value.isNotEmpty) {
              final parsed = int.tryParse(value);
              if (parsed == null || parsed <= 0) {
                rowErrors.add(ImportError(row: rowNumber, col: colNumber, type: 'type', message: t('import.lifetimeInvalid', locale), fieldName: fieldName));
              } else {
                plannedLifetimeDays = parsed;
              }
            }
            break;

          case 9:
            if (value.isNotEmpty) {
              final parsed = int.tryParse(value);
              if (parsed == null || parsed < 0 || parsed > 5) {
                rowErrors.add(ImportError(row: rowNumber, col: colNumber, type: 'range', message: t('import.ratingInvalid', locale), fieldName: fieldName));
              } else {
                rating = parsed;
              }
            }
            break;

          case 10:
            if (value.isNotEmpty) {
              tags = value.split(RegExp(r'[;；,，]')).map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
            }
            break;

          case 11:
            notes = value;
            break;

          case 12:
            if (value.isNotEmpty) {
              final statusLower = value.toLowerCase();
              if (locale == 'zh') {
                if (statusLower.contains('归档')) {
                  isArchived = true;
                } else if (statusLower.contains('删除')) {
                  isDeleted = true;
                }
              } else {
                if (statusLower.contains('archived')) {
                  isArchived = true;
                } else if (statusLower.contains('deleted')) {
                  isDeleted = true;
                }
              }
            }
            break;

          case 13:
            warrantyPeriod = value.isNotEmpty ? value : null;
            break;

          case 14:
            if (value.isNotEmpty) {
              final parsed = _parseDate(value);
              if (parsed == null) {
                rowErrors.add(ImportError(row: rowNumber, col: colNumber, type: 'format', message: t('import.dateInvalid', locale), fieldName: fieldName));
              } else {
                warrantyExpiry = parsed;
              }
            }
            break;

          case 15:
            insuranceInfo = value.isNotEmpty ? value : null;
            break;
        }
      }

      if (rowErrors.isNotEmpty) {
        errors.addAll(rowErrors);
      } else if (name != null && category != null && price != null && purchaseDate != null) {
        validItems.add(AssetItem.create(
          name: name,
          category: category,
          brand: brand,
          price: price,
          purchaseDate: purchaseDate,
          plannedLifetimeDays: plannedLifetimeDays,
          rating: rating,
          tags: tags,
          notes: notes,
          warrantyPeriod: warrantyPeriod,
          warrantyExpiry: warrantyExpiry,
          insuranceInfo: insuranceInfo,
        ).copyWith(
          isArchived: isArchived,
          isDeleted: isDeleted,
        ));
      }
    }

    return ImportResult(
      validItems: validItems,
      errors: errors,
      totalRows: lines.length - 1,
    );
  }

  static Map<String, String> _buildCategoryMap(String locale) {
    if (locale == 'zh') {
      return {
        '电子产品': '电子产品',
        '服装鞋帽': '服装鞋帽',
        '食品饮料': '食品饮料',
        '家居用品': '家居用品',
        '图书教育': '图书教育',
        '运动户外': '运动户外',
        '美妆护肤': '美妆护肤',
        '交通工具': '交通工具',
        '医疗健康': '医疗健康',
        '礼品玩具': '礼品玩具',
        '宠物用品': '宠物用品',
        '其他': '其他',
        'electronics': '电子产品',
        'clothing': '服装鞋帽',
        'food': '食品饮料',
        'food & drinks': '食品饮料',
        'home': '家居用品',
        'books': '图书教育',
        'sports': '运动户外',
        'beauty': '美妆护肤',
        'transport': '交通工具',
        'medical': '医疗健康',
        'gifts': '礼品玩具',
        'pets': '宠物用品',
        'other': '其他',
      };
    } else {
      return {
        'electronics': '电子产品',
        'clothing': '服装鞋帽',
        'food': '食品饮料',
        'food & drinks': '食品饮料',
        'home': '家居用品',
        'books': '图书教育',
        'sports': '运动户外',
        'beauty': '美妆护肤',
        'transport': '交通工具',
        'medical': '医疗健康',
        'gifts': '礼品玩具',
        'pets': '宠物用品',
        'other': '其他',
        '电子产品': '电子产品',
        '服装鞋帽': '服装鞋帽',
        '食品饮料': '食品饮料',
        '家居用品': '家居用品',
        '图书教育': '图书教育',
        '运动户外': '运动户外',
        '美妆护肤': '美妆护肤',
        '交通工具': '交通工具',
        '医疗健康': '医疗健康',
        '礼品玩具': '礼品玩具',
        '宠物用品': '宠物用品',
        '其他': '其他',
      };
    }
  }

  static bool _isValidCategory(String category, List<String> validCategories) {
    return validCategories.contains(category) ||
           AppConstants.presetCategories.any((c) => c['name'] == category);
  }

  static DateTime? _parseDate(String value) {
    final patterns = [
      RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$'),
      RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(value.trim());
      if (match != null) {
        final year = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final day = int.parse(match.group(3)!);
        try {
          return DateTime(year, month, day);
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  static String _getFieldName(int col, String locale) {
    final names = [
      t('csv.name', locale),
      t('csv.category', locale),
      t('csv.brand', locale),
      t('csv.price', locale),
      t('csv.purchaseDate', locale),
      t('csv.daysUsed', locale),
      t('csv.dailyCost', locale),
      t('csv.remainingValue', locale),
      t('csv.plannedLifetime', locale),
      t('csv.rating', locale),
      t('csv.tags', locale),
      t('csv.notes', locale),
      t('csv.status', locale),
      t('csv.warranty', locale),
      t('csv.warrantyExpiry', locale),
      t('csv.insurance', locale),
    ];
    return col < names.length ? names[col] : '';
  }

  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());

    return result;
  }

  static String _escapeCsvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

Future<String> getPublicDownloadsPath() async {
  if (Platform.isAndroid) {
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
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