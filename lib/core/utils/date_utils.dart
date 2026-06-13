import 'package:intl/intl.dart';

/// 日期工具类
class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat _monthFmt = DateFormat('yyyy-MM');
  static final DateFormat _yearFmt = DateFormat('yyyy');
  static final DateFormat _shortFmt = DateFormat('MM/dd');
  static final DateFormat _weekdayFmt = DateFormat('EEEE');
  static final DateFormat _cnFmt = DateFormat('yyyy年MM月dd日');
  static final DateFormat _monthDayFmt = DateFormat('MM月dd日');

  /// 格式化日期
  static String formatDate(DateTime date) => _dateFmt.format(date);

  /// 格式化日期时间
  static String formatDateTime(DateTime date) => _dateTimeFmt.format(date);

  /// 格式化年月
  static String formatMonth(DateTime date) => _monthFmt.format(date);

  /// 格式化年份
  static String formatYear(DateTime date) => _yearFmt.format(date);

  /// 中文日期
  static String formatCn(DateTime date) => _cnFmt.format(date);

  /// 短日期 (MM/dd)
  static String formatShort(DateTime date) => _shortFmt.format(date);

  /// 月日中文
  static String formatMonthDay(DateTime date) => _monthDayFmt.format(date);

  /// 计算从购买日到现在的天数
  static int daysSince(DateTime purchaseDate) {
    final now = DateTime.now();
    final diff = now.difference(purchaseDate);
    return diff.inDays < 0 ? 0 : diff.inDays;
  }

  /// 计算日均成本
  static double dailyCost(double price, DateTime purchaseDate) {
    final days = daysSince(purchaseDate);
    if (days == 0) return price;
    return price / (days + 1);
  }

  /// 计算预计淘汰日期（按计划使用天数）
  static DateTime? estimateEndDate(
    DateTime purchaseDate,
    int plannedDays,
  ) {
    return purchaseDate.add(Duration(days: plannedDays));
  }

  /// 剩余价值百分比
  static double remainingValuePercent(
    DateTime purchaseDate,
    int plannedLifetimeDays,
  ) {
    final used = daysSince(purchaseDate);
    if (used >= plannedLifetimeDays) return 0;
    return (plannedLifetimeDays - used) / plannedLifetimeDays;
  }

  /// 判断是否在同一个月
  static bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  /// 判断是否在同一年
  static bool isSameYear(DateTime a, DateTime b) {
    return a.year == b.year;
  }

  /// 获取某月第一天
  static DateTime monthStart(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// 获取某月最后一天
  static DateTime monthEnd(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59);
  }

  /// 获取本周一
  static DateTime weekStart(DateTime date) {
    final dayOfWeek = date.weekday;
    return DateTime(date.year, date.month, date.day - dayOfWeek + 1);
  }

  /// 友好的相对时间描述
  static String friendlyRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays < 0) return 'Future';
    if (diff.inDays == 0) {
      if (diff.inHours < 1) return 'Just now';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7}w ago';
    if (diff.inDays < 365) return '${diff.inDays ~/ 30}mo ago';
    return '${diff.inDays ~/ 365}y ago';
  }

  /// 获取过去 N 个月的月份列表（含当月）
  static List<DateTime> lastMonths(int count) {
    final now = DateTime.now();
    return List.generate(
      count,
      (i) => DateTime(now.year, now.month - i, 1),
    );
  }
}
