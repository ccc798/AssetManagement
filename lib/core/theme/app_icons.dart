import 'package:flutter/material.dart';

/// 自定义矢量图标 — 使用 CustomPainter 绘制
///
/// 分类图标索引:
/// electronics, clothing, food, home, book, sports, beauty,
/// transport, medical, gift, pet, other
class AppIcons {
  AppIcons._();

  static const Map<String, IconData> materialIcons = {
    'electronics': Icons.devices,
    'clothing': Icons.checkroom,
    'food': Icons.restaurant,
    'home': Icons.home,
    'book': Icons.menu_book,
    'sports': Icons.sports_soccer,
    'beauty': Icons.face,
    'transport': Icons.directions_car,
    'medical': Icons.medical_services,
    'gift': Icons.card_giftcard,
    'pet': Icons.pets,
    'other': Icons.category,
  };

  /// 获取 Material Design 图标
  static IconData getIcon(String iconName) {
    return materialIcons[iconName] ?? Icons.category;
  }

  /// 获取分类对应的彩色图标 Widget
  static Widget categoryIcon(String iconName, String colorHex,
      {double size = 24}) {
    return Icon(
      getIcon(iconName),
      size: size,
      color: _parseColor(colorHex),
    );
  }

  static Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

/// 空状态矢量图
class EmptyStatePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 盒子主体
    final boxPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final boxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.6,
        height: size.height * 0.5,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(boxRect, boxPaint);

    // 盒子开口
    final lidPaint = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final lidPath = Path()
      ..moveTo(center.dx - size.width * 0.3, center.dy - size.height * 0.25)
      ..lineTo(center.dx - size.width * 0.25, center.dy - size.height * 0.32)
      ..lineTo(center.dx + size.width * 0.25, center.dy - size.height * 0.32)
      ..lineTo(center.dx + size.width * 0.3, center.dy - size.height * 0.25);

    canvas.drawPath(lidPath, lidPaint);

    // 问号
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(
          fontSize: 40,
          color: Color(0xFFBDBDBD),
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy + textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant EmptyStatePainter oldDelegate) => false;
}
