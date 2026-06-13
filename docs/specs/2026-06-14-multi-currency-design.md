# 多币种支持设计

**目标：** 支持不同币种记录资产价格，统一按基准币种统计汇总

---

## 数据模型

### AssetItem 新增字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `currency` | String | `'CNY'` | 物品的计价币种代码 |

### BackupConfig 新增字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `baseCurrency` | String | `'CNY'` | 统计时使用的基准币种 |

---

## 汇率表

硬编码常用货币汇率（相对于 CNY），不依赖外部 API：

| 代码 | 名称 | 符号 | 兑 CNY 汇率 |
|------|------|------|------------|
| CNY | 人民币 | ¥ | 1.0 |
| USD | 美元 | \$ | 7.2 |
| EUR | 欧元 | € | 7.8 |
| GBP | 英镑 | £ | 9.1 |
| JPY | 日元 | ¥ | 0.05 |
| KRW | 韩元 | ₩ | 0.005 |
| HKD | 港币 | HK$ | 0.92 |
| TWD | 台币 | NT$ | 0.22 |

---

## UI 改动

### 添加/编辑物品页

在「品牌 + 价格」行中，价格输入框旁添加币种下拉选择器：

```
品牌: [______]  价格: [____] [CNY ▾]
```

### 物品详情页

价格显示带上币种符号：

```
¥ 9,999.00 (CNY)
```

### 首页总资产统计

按基准币种转换后显示：

```
总资产: ¥ 15,234.00
```

### 统计页

所有金额按基准币种转换后汇总。

### 设置页

在「AI 智能识别」下方添加「币种设置」：

```
💱 币种设置
  基准币种: CNY
```

---

## 汇率工具类

```dart
class CurrencyUtil {
  static const Map<String, Map<String, dynamic>> currencies = {
    'CNY': {'symbol': '¥', 'name': '人民币', 'rate': 1.0},
    'USD': {'symbol': '\$', 'name': '美元', 'rate': 7.2},
    ...
  };

  /// 转换金额到基准币种
  static double convertToBase(double amount, String from, String to);

  /// 格式化金额（带币种符号）
  static String format(double amount, String currency);
}
```

---

## 文件清单

| 文件 | 操作 |
|------|------|
| `lib/data/models/asset_item.dart` | 添加 `currency` 字段 |
| `lib/data/models/backup_config.dart` | 添加 `baseCurrency` 字段 |
| `lib/data/database/config_dao.dart` | 添加 baseCurrency 读写 |
| `lib/core/utils/money_utils.dart` | 扩展为 CurrencyUtil，支持多币种格式化+转换 |
| `lib/ui/pages/add_item/add_item_page.dart` | 价格行添加币种选择器 |
| `lib/ui/pages/item_detail/item_detail_page.dart` | 价格显示币种符号 |
| `lib/ui/pages/statistics/statistics_page.dart` | 统计转换为基准币种 |
| `lib/core/utils/csv_export.dart` | CSV 添加币种列 |
