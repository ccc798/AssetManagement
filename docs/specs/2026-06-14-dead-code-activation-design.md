# 亡代码激活 + 细节补全设计

**目标：** 将已写完但未接入 UI 的代码上线，补全缺失的交互路径

---

## 1. 详情页显示截图卡片

**状态：** `_buildScreenshotCard()` 已写完但未被 `build()` 调用

**改动：** 在详情页「备注」卡片之后，如果有截图路径则显示截图卡片

```
详情页 body:
  ├─ 头部信息卡
  ├─ 详细信息卡
  ├─ 价值分析卡
+ ├─ 截图卡片（if screenshotPath.isNotEmpty）
  └─ 备注卡片（if notes.isNotEmpty）
```

---

## 2. 详情页显示 AI 数据卡片

**状态：** `_buildAiDataCard()` 已写完但未被 `build()` 调用

**改动：** 在详情页底部，如果 `aiRawData.isNotEmpty` 则显示 AI 识别数据卡片

如果用户是用手动添加的（无 AI 数据），这行不会显示。

---

## 3. 「从文字识别」入口

**状态：** `AiService.recognizeFromText()` 已实现但无 UI 入口

**改动：** 在 AddItemPage 的「截图识别」按钮下拉菜单中增加「文字识别」选项

```
截图识别按钮 → 弹出菜单:
  ├─ 📷 截图识别（已有）
  └─ 📝 文字识别（新增）
```

点击「文字识别」→ 弹出对话框让用户粘贴收据文本 → AI 识别 → 同多物品逐件保存流程

---

## 4. AI 增强入口

**状态：** `AiService.enrichItemInfo()` 已实现但无 UI 入口

**改动：** 在 AddItemPage 提交表单后，如果有 AI 配置且非 AI 识别来源，可调用 enrichItemInfo 自动补充分类/标签

**实施方式：** 在 `_submit()` 中，手动添加模式保存成功后，静默调用 enrichItemInfo 更新物品标签（不影响用户操作流）

---

## 5. 硬删除功能

**状态：** 只有软删除（isDeleted），无法彻底清理

**改动：** 
- `DatabaseManager` 新增 `hardDelete(int id)` 方法
- 已归档分类中，已删除物品的卡片增加「彻底删除」按钮（红色，需二次确认）

---

## 6. 清理无用的代码/依赖

- 移除 `share_plus` 引用（已不再使用），保留依赖以防后续
- 移除 `pageSize = 20` 常量（未使用）
- 不用改动其他

---

## 文件清单

| 文件 | 操作 |
|------|------|
| `lib/ui/pages/item_detail/item_detail_page.dart` | build 中加入 screenshot + aiData 卡片 |
| `lib/ui/pages/add_item/add_item_page.dart` | 截图按钮改为下拉菜单 + 文字识别对话框 |
| `lib/ui/pages/home/home_page.dart` | 已归档列表加硬删除按钮 |
| `lib/data/database/database_manager.dart` | 新增 `hardDelete()` 方法 |
| `lib/data/database/asset_dao.dart` | 新增 `hardDelete()` 透传 |
| `lib/core/constants/app_constants.dart` | 移除未使用的 `pageSize` |

---

## 验收

1. 有截图的物品点进详情页能看到截图
2. 有 AI 数据的物品点进详情页能看到原始识别数据
3. 添加页可以用粘贴文字的方式让 AI 识别物品
4. 手动添加物品时自动 AI 补充分类/标签（不影响流程）
5. 归档页中可彻底删除已删除物品
6. 不引入新 bug，不影响现有功能
