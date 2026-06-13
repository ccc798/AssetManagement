# 保修/保险字段设计

**目标：** 为物品添加保修和保险信息字段，非必填，未填时详情页不显示

---

## 数据模型

### AssetItem 新增字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `warrantyPeriod` | `String?` | null | 保修期限描述，如「1年」「2年 延保」「终身保修」 |
| `warrantyExpiry` | `DateTime?` | null | 保修到期日期（可选日期选择） |
| `insuranceInfo` | `String?` | null | 保险信息，如「中国人保 财产险 保单号 PICC2026xxxx」 |

所有字段均为 **nullable**（null = 未填写），toJson 时如果为 null 不序列化或存 null。

---

## UI 设计

### 添加/编辑页（AddItemPage）

在「备注」字段之后、「提交按钮」之前，插入一个可折叠的「保修与保险」区域：

```
▶ 保修与保险（选填）    ← 可折叠卡片
  ┌─────────────────────┐
  │ 保修期限             │
  │ [ 1年  ] [ 2年 ] [ 3年 ] [ 自定义: _____ ]  │  ← Chip 预设 + 自由输入
  │                     │
  │ 保修到期             │
  │ [选择日期 ── ]       │  ← 可选日期选择器
  │                     │
  │ 保险信息             │
  │ [__________________] │  ← 多行文本框
  │ 保险公司、保单号等    │
  └─────────────────────┘
```

- 默认折叠状态（`ExpansionTile` 或手动控制的 `AnimatedCrossFade`）
- 编辑时如果有已填写数据，自动展开
- 所有字段均无验证器（不填不影响提交）

### 详情页（ItemDetailPage）

在「详细信息」卡片底部，如果有保修/保险数据则显示：

```
保修期限: 1年
保修到期: 2027-06-12
保险信息: 中国人保 财产险
```

使用已有的 `_detailRow` 模式，图标分别为 `Icons.verified`、`Icons.event`、`Icons.security`。

如果没有任何一个字段有值，不显示额外行。

---

## CSV 导出

在 `csv_export.dart` 的 `_buildCsv` 方法中：

| 列 | 字段 |
|---|------|
| 保修期限 | `item.warrantyPeriod ?? ''` |
| 保修到期 | `item.warrantyExpiry` 格式化 |
| 保险信息 | `item.insuranceInfo ?? ''` |

---

## 文件清单

| 文件 | 操作 | 职责 |
|------|------|------|
| `lib/data/models/asset_item.dart` | 修改 | 添加 3 个字段 + toJson/fromJson/copyWith/create |
| `lib/ui/pages/add_item/add_item_page.dart` | 修改 | 添加保修/保险输入区域 |
| `lib/ui/pages/item_detail/item_detail_page.dart` | 修改 | 显示保修/保险信息 |
| `lib/core/utils/csv_export.dart` | 修改 | CSV 包含新字段 |

---

## 验收标准

1. 「添加物品」页面可展开保修/保险区域，填写后保存
2. 「编辑物品」页面如果已有数据则自动展开
3. 「详情页」有数据时显示、无数据时不显示
4. CSV 导出包含新字段
5. 不填任何新字段、仅填原有字段 → 保存正常，不影响原有流程
6. 旧数据（无新字段）加载正常，不报错
