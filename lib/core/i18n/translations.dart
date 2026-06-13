import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/config_dao.dart';
import 'locales/zh.dart';
import 'locales/en.dart';

/// ── 语言检测 ──

bool isSystemChinese() {
  final locale = WidgetsBinding.instance.platformDispatcher.locale;
  return locale.languageCode == 'zh';
}

/// 用户选择：'system'(跟随系统) / 'zh' / 'en'
final localeSettingProvider = StateProvider<String>((ref) => 'system');

/// 解析后的实际语言代码
final localeCodeProvider = Provider<String>((ref) {
  final setting = ref.watch(localeSettingProvider);
  // 如果用户明确选择了某种语言
  if (_allLocales.containsKey(setting)) return setting;
  // 跟随系统：检测系统语言是否匹配已注册的语言
  if (setting == 'system') {
    final sysLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final langCode = sysLocale.languageCode;
    if (_allLocales.containsKey(langCode)) return langCode;
    // 也检查 locale.countryCode（如 zh_CN, zh_TW）
    final fullCode = sysLocale.toString().replaceAll('_', '-');
    if (_allLocales.containsKey(fullCode)) return fullCode;
  }
  // 默认英文
  return 'en';
});

/// 初始化语言设置（从 ConfigDao 读取）
final localeInitProvider = FutureProvider<void>((ref) async {
  final dao = ConfigDao();
  final config = await dao.getConfig();
  ref.read(localeSettingProvider.notifier).state = config.locale;
});

/// Extension on WidgetRef to easily get locale
extension LocaleRef on WidgetRef {
  String get locale => watch(localeCodeProvider);
  String get localeRead => read(localeCodeProvider);
}

/// ── 翻译函数 ──
///
/// 使用方式：t('home.title', locale)
/// 添加新语言：
///   1. 在 lib/core/i18n/locales/ 下创建 <code>.dart（如 ja.dart）
///   2. 导出 const Map<String, String> ja = { ... }
///   3. 在 _allLocales 中注册：'ja': ja
///   4. 在 localeCodeProvider 中添加语言代码判断

String t(String key, String locale) {
  return Translations.get(key, locale);
}

/// 所有已注册的语言映射表
///
/// key = 语言代码（如 'zh', 'en'）
/// value = 该语言的翻译 Map
final Map<String, Map<String, String>> _allLocales = {
  'zh': zh,
  'en': en,
};

/// 支持的语言代码列表（用于 UI 下拉选择等）
final List<String> supportedLocales = _allLocales.keys.toList();

class Translations {
  Translations._();

  /// 获取翻译文本
  ///
  /// 查找顺序：
  /// 1. 目标语言
  /// 2. 英文（fallback）
  /// 3. 返回 key 本身
  static String get(String key, String locale) {
    final langMap = _allLocales[locale];
    if (langMap != null) {
      final value = langMap[key];
      if (value != null) return value;
    }
    // Fallback to English
    final enMap = _allLocales['en'];
    if (enMap != null) {
      final enValue = enMap[key];
      if (enValue != null) return enValue;
    }
    return key;
  }

  /// 注册新的语言（用于动态添加）
  static void registerLocale(String code, Map<String, String> translations) {
    _allLocales[code] = translations;
  }
}
