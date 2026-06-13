import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ui/widgets/app_toast.dart';
import '../../data/models/asset_item.dart';
import '../../ui/providers/asset_provider.dart';
import 'i18n/translations.dart';

/// 统一物品操作 — 归档/删除/保存
///
/// 所有页面通过此类执行物品操作，确保：
/// 1. 操作后自动刷新列表（bumpVersion）
/// 2. 操作后弹出统一风格提示（Toast.capsule）
class ItemOp {
  ItemOp._();

  /// 归档物品（设置 isArchived = true）
  static Future<void> archive(WidgetRef ref, BuildContext context, AssetItem item) async {
    final dao = ref.read(assetDaoProvider);
    await dao.update(item.copyWith(isArchived: true));
    ref.bumpVersion();
    if (context.mounted) {
      AppToast.capsule(context, t('toast.archived', ref.read(localeCodeProvider)), Colors.blue);
    }
  }

  static Future<void> delete(WidgetRef ref, BuildContext context, AssetItem item) async {
    final dao = ref.read(assetDaoProvider);
    await dao.softDelete(item.id);
    ref.bumpVersion();
    if (context.mounted) {
      AppToast.capsule(context, t('toast.deleted', ref.read(localeCodeProvider)), Colors.red);
    }
  }
}
