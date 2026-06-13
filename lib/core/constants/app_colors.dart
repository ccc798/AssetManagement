import 'package:flutter/material.dart';

/// 应用调色板
class AppColors {
  AppColors._();

  // 主色
  static const Color primary = Color(0xFF5C6BC0); // Indigo 400
  static const Color primaryLight = Color(0xFF8E99D3);
  static const Color primaryDark = Color(0xFF3949AB);

  // 强调色
  static const Color accent = Color(0xFFFF7043); // Deep Orange 400
  static const Color accentLight = Color(0xFFFFAB91);

  // 功能色
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFCA28);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);

  // 中性色
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFBDBDBD);

  // 深色主题
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2C2C2C);
  static const Color darkTextPrimary = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFF9E9E9E);

  /// 从十六进制字符串转 Color
  static Color fromHex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
