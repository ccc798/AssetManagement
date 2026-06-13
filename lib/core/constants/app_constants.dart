/// 应用全局常量
class AppConstants {
  AppConstants._();

  /// 应用名称
  static const String appName = 'Asset Management';

  /// 版本号（由 build_all.ps1 自动更新）
  static const String appVersion = '0.0.1';
  static const String buildNumber = '26061309';
  static const String appVersionFull = '$appVersion+$buildNumber';

  /// 数据库
  static const String dbName = 'asset_management.db';
  static const int dbVersion = 1;

  /// 默认货币
  static const String defaultCurrency = '¥';
  static const String currencyCode = 'CNY';

  /// 日期格式
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String monthFormat = 'yyyy-MM';
  static const String yearFormat = 'yyyy';

  /// AI 默认配置
  static const String defaultAiBaseUrl = 'https://api.openai.com/v1';
  static const String defaultAiModel = 'gpt-4o-mini';
  static const int defaultAiMaxTokens = 4096;
  static const double defaultAiTemperature = 0.1;

  /// 备份
  static const String backupFileName = 'asset_management_backup.json';
  static const String backupMimeType = 'application/octet-stream';

  /// 预设分类
  /// 预设分类名 → 翻译键映射
  static String getCategoryNameKey(String name) {
    const map = {
      '电子产品': 'category.electronics',
      '服装鞋帽': 'category.clothing',
      '食品饮料': 'category.food',
      '家居用品': 'category.home',
      '图书教育': 'category.book',
      '运动户外': 'category.sports',
      '美妆护肤': 'category.beauty',
      '交通工具': 'category.transport',
      '医疗健康': 'category.medical',
      '礼品玩具': 'category.gift',
      '宠物用品': 'category.pet',
      '其他': 'category.other',
    };
    return map[name] ?? 'category.other';
  }

  static const List<Map<String, String>> presetCategories = [
    {'name': '电子产品', 'icon': 'electronics', 'color': '#2196F3'},
    {'name': '服装鞋帽', 'icon': 'clothing', 'color': '#E91E63'},
    {'name': '食品饮料', 'icon': 'food', 'color': '#FF9800'},
    {'name': '家居用品', 'icon': 'home', 'color': '#4CAF50'},
    {'name': '图书教育', 'icon': 'book', 'color': '#9C27B0'},
    {'name': '运动户外', 'icon': 'sports', 'color': '#00BCD4'},
    {'name': '美妆护肤', 'icon': 'beauty', 'color': '#F06292'},
    {'name': '交通工具', 'icon': 'transport', 'color': '#607D8B'},
    {'name': '医疗健康', 'icon': 'medical', 'color': '#F44336'},
    {'name': '礼品玩具', 'icon': 'gift', 'color': '#FF5722'},
    {'name': '宠物用品', 'icon': 'pet', 'color': '#795548'},
    {'name': '其他', 'icon': 'other', 'color': '#9E9E9E'},
  ];

  /// 根据分类名获取颜色 hex
  static String getCategoryColorHex(String name) {
    for (final cat in presetCategories) {
      if (cat['name'] == name) return cat['color'] ?? '#9E9E9E';
    }
    return '#9E9E9E';
  }

  /// 根据分类名获取图标名
  static String getCategoryIconName(String name) {
    for (final cat in presetCategories) {
      if (cat['name'] == name) return cat['icon'] ?? 'other';
    }
    return 'other';
  }
}
















