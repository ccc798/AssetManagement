import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/config_dao.dart';

/// 预置配色方案
class ColorSchemeOption {
  final String name;
  final Color seed;
  const ColorSchemeOption({required this.name, required this.seed});
}

const List<ColorSchemeOption> presetColorSchemes = [
  ColorSchemeOption(name: '靛蓝', seed: Color(0xFF5C6BC0)),
  ColorSchemeOption(name: '天蓝', seed: Color(0xFF42A5F5)),
  ColorSchemeOption(name: '青绿', seed: Color(0xFF26A69A)),
  ColorSchemeOption(name: '翠绿', seed: Color(0xFF66BB6A)),
  ColorSchemeOption(name: '橙色', seed: Color(0xFFFF9800)),
  ColorSchemeOption(name: '玫红', seed: Color(0xFFEC407A)),
  ColorSchemeOption(name: '紫色', seed: Color(0xFFAB47BC)),
  ColorSchemeOption(name: '红色', seed: Color(0xFFD32F2F)),
];

/// ThemeMode 解析
ThemeMode parseThemeMode(String mode) {
  switch (mode) {
    case 'light': return ThemeMode.light;
    case 'dark': return ThemeMode.dark;
    default: return ThemeMode.system;
  }
}

String themeModeToString(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light: return 'light';
    case ThemeMode.dark: return 'dark';
    default: return 'system';
  }
}

/// ——— Provider ———

/// 用户选择的明暗模式
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// 用户选择的主题色种子
final colorSeedProvider = StateProvider<Color>((ref) => const Color(0xFF5C6BC0));

/// 初始化主题配置（从 ConfigDao 读取并设置到 StateProvider）
final themeInitProvider = FutureProvider<void>((ref) async {
  final dao = ConfigDao();
  final config = await dao.getThemeConfig();
  final mode = config['themeMode'] as String? ?? 'system';
  final seed = config['colorSeed'] as int? ?? 0xFF5C6BC0;
  ref.read(themeModeProvider.notifier).state = parseThemeMode(mode);
  ref.read(colorSeedProvider.notifier).state = Color(seed);
});

/// 生成的完整主题对（供 app.dart 消费）
final appThemeProvider = Provider<({ThemeData light, ThemeData dark, ThemeMode mode})>((ref) {
  final mode = ref.watch(themeModeProvider);
  final seed = ref.watch(colorSeedProvider);
  return (light: AppTheme.light(seed), dark: AppTheme.dark(seed), mode: mode);
});
