# CSV 导出功能设计

**目标：** 将资产数据导出为 CSV 文件，可在 Excel/WPS/Numbers 中打开分析

**架构：** 在设置页新增「导出数据」入口 → ExportPage（选择范围）→ CsvExporter（生成CSV）→ 保存到设备

**技术栈：** dart:io + dart:convert（无新增依赖）

---

## UI 设计

### 入口
设置页新增一行（位于「AI 智能识别」和「WebDAV 远程备份」之间）：

```
📤 导出数据
  将资产数据导出为 CSV 文件
  >
```

### 导出页（ExportPage）
- AppBar: 「导出数据」
- 范围选择（Radio/ChoiceChip）：全部 / 使用中 / 已归档
- 字段预览（只读列表，让用户知道会导出什么）
- 底部按钮：「导出 CSV」

### 交互流程

```
用户打开设置页 → 点击「导出数据」
    ↓
选择导出范围 → 点击「导出 CSV」
    ↓
生成 CSV → 保存到文件
    ↓
Toast: 「已导出到 /xxx/资产数据_2026-06-12.csv」
    ↓
(可选) 弹出分享对话框
```

---

## CSV 格式

### 表头
| 中文 | 字段 | 说明 |
|------|------|------|
| 名称 | name | AssetItem.name |
| 分类 | category | AssetItem.category |
| 品牌 | brand | AssetItem.brand |
| 价格 | price | AssetItem.price |
| 购买日期 | purchaseDate | yyyy-MM-dd |
| 已用天数 | daysUsed | 计算字段 |
| 日均成本 | dailyCost | 计算字段 |
| 剩余价值 | remainingValue | 百分比 (remainingValueRatio × 100) |
| 计划期限 | plannedLifetimeDays | AssetItem.plannedLifetimeDays |
| 评分 | rating | AssetItem.rating |
| 标签 | tags | AssetItem.tags.join('; ') |
| 备注 | notes | AssetItem.notes |
| 状态 | status | active / archived / deleted |

### 文件命名
`资产数据_yyyy-MM-dd.csv`

### CSV 规则
- UTF-8 BOM（确保 Excel 正确识别中文）
- 逗号分隔
- 字段含逗号/换行时用双引号包裹

---

## 平台处理

| 平台 | 保存路径 |
|------|----------|
| Android | `getApplicationDocumentsDirectory()` |
| Windows | `getApplicationDocumentsDirectory()` + 复制到桌面 |
| iOS | `getApplicationDocumentsDirectory()` |

所有平台均通过 Toast 显示文件路径。

---

## 文件清单

| 文件 | 职责 |
|------|------|
| `lib/core/utils/csv_export.dart` | CSV 生成工具函数 |
| `lib/ui/pages/settings/export_page.dart` | 导出 UI 页面 |
| `lib/ui/pages/settings/settings_page.dart` | 新增导出入口 |

### csv_export.dart API

```dart
class CsvExporter {
  /// 导出资产数据到 CSV 文件
  /// [items] 要导出的物品列表
  /// 返回保存的文件路径，失败抛出异常
  static Future<String> export(List<AssetItem> items) async { ... }
}
```

### ExportPage 参数

```dart
class ExportPage extends ConsumerWidget {
  const ExportPage({super.key});
  // 从 provider 读取 assetListProvider / archivedListProvider / getAll
}
```

---

## 验收标准

1. 点击导出 → 生成 CSV 文件，Toast 显示路径
2. CSV 可用 Excel/WPS 直接打开，中文正常显示
3. 「全部」包含使用中 + 已归档 + 已删除（标记 status 列）
4. 「使用中」只包含未归档未删除
5. 「已归档」只包含已归档未删除
6. 导出不改变任何数据
