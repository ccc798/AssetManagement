import 'package:flutter/material.dart';

/// 应用内统一提示工具
///
/// 分类：
///   capsule  — 用户触发的操作结果（保存/归档/删除），顶部中间胶囊
///   bottom   — 系统操作结果（连接测试结果），底部浮动条
///   loading  — 系统操作进行中（测试中），底部浮动条+转圈
class AppToast {
  AppToast._();

  /// 顶部中间胶囊形提示 — 用于用户触发的操作
  ///
  /// 使用 Overlay 实现，确保出现在屏幕顶部正中。
  /// 胶囊宽度 = 文本宽度 + 40% 余量。
  static void capsule(BuildContext context, String message, Color color) {
    final overlay = Overlay.of(context);
    final textSpan = TextSpan(
      text: message,
      style: const TextStyle(color: Colors.white, fontSize: 14),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
      ..layout();
    // 胶囊宽度 = 文本宽度 + 左右 padding(40) + 25% 余量
    // 确保 padding 后的可用空间能容纳文本
    final capsuleWidth = (tp.width * 1.25 + 40).clamp(100.0, 400.0);

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 50,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: capsuleWidth,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry?.remove());
  }

  /// 底部标准 SnackBar — 用于系统操作结果
  static void bottom(BuildContext context, String message, Color color,
      {int seconds = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: seconds),
      ),
    );
  }

  /// 底部加载中 SnackBar
  static void loading(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.blueGrey,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 30),
      ),
    );
  }

  /// 清除当前 SnackBar
  static void dismiss(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }
}
