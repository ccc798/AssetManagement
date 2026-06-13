# 分类管理设计

**目标：** 用户可自定义增删改分类（名称/图标/颜色），取代当前硬编码 12 个预设

---

## 架构

```
CategoryDao（状态化单例）
  ├─ 读取/写入 {docDir}/asset_management_categories.json
  ├─ 首次启动 → 从 AppConstants.presetCategories 写入默认值
  ├─ add() / update() / delete() / reorder()
  └─ getActive() / getAll()

category_provider.dart
  ├─ categoryListProvider（FutureProvider → 监听 version 变化自动刷新）
  └─ categoryVersionProvider（StateProvider — 写操作后 bump）

CategoryManagementPage（设置页入口）
  ├─ 列表展示所有分类（预设标记不可删除，可编辑颜色/图标）
  ├─ 右上角 + 按钮添加新分类
  └─ 点击分类 → 编辑（名称/图标/颜色）
```

---

## CategoryDao 改造

从静态只读改为**状态化单例**（类似 ConfigDao）：

```dart
class CategoryDao {
  static final CategoryDao _instance = CategoryDao._internal();
  factory CategoryDao() => _instance;

  List<CategoryItem> _categories = [];
  String? _filePath;

  Future<void> _ensureLoaded() async { ... }  // 从文件加载，首次写入预设
  Future<void> _save() async { ... }

  Future<List<CategoryItem>> getActive() async { ... }  // isDeleted == false
  Future<CategoryItem?> getByName(String name) async { ... }

  Future<CategoryItem> add(String name, String icon, String colorHex) async { ... }
  Future<CategoryItem> update(int id, {String? name, String? icon, String? colorHex}) async { ... }
  Future<void> delete(int id) async { ... }  // 软删除（isDeleted=true）
}
```

**预设分类不可被删除**（`category.isDeleted` 不适用于预设），但**可以被编辑**（颜色/图标）。

---

## 图标选择器

从 `AppIcons.materialIcons` 中选取可用图标。在编辑/添加页面中展示为 Grid：

```
🖥️ 👗 🍔 🏠 📚 ⚽
💄 🚑 🚑 🎁 🐶 📦
```

每个可选图标以圆形按钮展示。

---

## 颜色选择器

从预置色板中选取（8 种常用色 + 自由 Hex 输入）：

```
🔴 🟠 🟡 🟢 🔵 🟣 🟤 ⚫
```

Hex 输入框：`#______`

---

## UI 页面

### CategoryManagementPage

```
设置 → [🏷️ 分类管理] → 新页面

AppBar: 分类管理 [+ 添加按钮]

列表：
  电子产品  🖥️  #2196F3  [预设]  [编辑]
  服装鞋帽  👗  #E91E63  [预设]  [编辑]
  ...
  自定义1   📦  #FF0000           [编辑] [删除]
```

### AddEditCategoryPage

弹出底部 Sheet 或全屏页：

```
名称: [______]
图标: [Grid 选择器]
颜色: [Grid 选择器 + Hex 输入]
──────────
[保存] [取消]
```

---

## 向后兼容

1. 已有物品的 `category` 字段存的是 **分类名称字符串**（如 "电子产品"），分类被编辑后，已有物品的分类名称保持不变
2. 分类被删除（软删除）后，已有物品的分类字符串不变，但在分类筛选器中不再显示
3. 预设分类的 `name` 不可编辑（防止已有数据错乱），但图标和颜色可自定义

---

## 文件清单

| 文件 | 操作 |
|------|------|
| `lib/data/database/category_dao.dart` | 重写为状态化单例，增/删/改/持久化 |
| `lib/ui/providers/category_provider.dart` | 新增 categoryVersionProvider |
| `lib/ui/pages/settings/category_management_page.dart` | 新建—分类管理页面 |
| `lib/ui/pages/settings/settings_page.dart` | 修改—新增分类管理入口 |
