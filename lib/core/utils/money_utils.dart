import '../i18n/translations.dart';

/// 金额格式化工具
class MoneyUtils {
  MoneyUtils._();

  /// 格式化金额，保留两位小数
  static String format(num amount, {String locale = 'zh'}) {
    return '${currency(locale)}${amount.toStringAsFixed(2)}';
  }

  /// 紧凑格式（大数字显示万/亿）
  static String formatCompact(num amount, {String locale = 'zh'}) {
    final abs = amount.abs();
    if (abs >= 100000000) {
      return '${currency(locale)}${(abs / 100000000).toStringAsFixed(2)}${t('money.100m', locale)}';
    } else if (abs >= 10000) {
      return '${currency(locale)}${(abs / 10000).toStringAsFixed(2)}${t('money.10k', locale)}';
    }
    return format(amount, locale: locale);
  }

  /// 获取货币符号
  static String currency(String locale) {
    return t('money.symbol', locale);
  }

  /// 日均成本描述
  static String dailyCostDescription(double dailyCost, {String locale = 'zh'}) {
    if (dailyCost < 0.01) return t('money.lessThan1cent', locale);
    return '${format(dailyCost, locale: locale)}${t('money.perDay', locale)}';
  }

  /// 简单说明 — 一杯奶茶对比
  static String dailyCostAnalogy(double dailyCost, {String locale = 'zh'}) {
    if (dailyCost < 0.5) return t('money.cheaperThanWater', locale);
    if (dailyCost < 5) return t('money.aboutSoyMilk', locale);
    if (dailyCost < 15) return t('money.aboutMilkTea', locale);
    if (dailyCost < 30) return t('money.aboutLunch', locale);
    if (dailyCost < 100) return t('money.aboutDinner', locale);
    return t('money.notCheap', locale);
  }
}
