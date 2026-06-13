# 导出流程修复设计

**问题：** `Share.shareXFiles` 在部分 Android 设备上提示「没有应用可执行此操作」。已添加 FileProvider 和 catch fallback，但仍未解决。

**根因：** 部分 Android 设备确实没有能处理 text/csv 的应用。catch 块虽然会保存文件到 temp，但 toast 提示「已保存到临时路径」用户无法找到文件。

## 修复方案

### 核心改动
无论是否分享成功，**始终先保存到文档目录**，确保用户知道文件位置。

### 流程

```
用户点击导出
  ↓
生成 CSV 并保存到 getApplicationDocumentsDirectory()
  ↓
Windows → Toast「已保存到桌面」
Android → 异步尝试分享（不阻塞，成功/失败都不影响已保存的文件）
          同时 Toast「已保存到 /asset_management/资产数据_xxx.csv」
```

### 文件变更

| 文件 | 改动 |
|------|------|
| `lib/core/utils/csv_export.dart` | 新增 `exportToDocuments()` 保存到文档目录 |
| `lib/ui/pages/settings/export_page.dart` | 改为「先保存再尝试分享」模式 |

### `exportToDocuments()` API

```dart
/// 保存 CSV 到应用文档目录，返回文件路径
static Future<String> exportToDocuments(List<AssetItem> items) async {
  final csv = _buildCsv(items);
  final dir = await getApplicationDocumentsDirectory();
  final fileName = '资产数据_${_formatDate(DateTime.now())}.csv';
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(csv, flush: true);
  return file.path;
}
```
