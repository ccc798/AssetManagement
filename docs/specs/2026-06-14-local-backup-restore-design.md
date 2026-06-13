# 本地备份/恢复设计

**目标：** 将「WebDAV 远程备份」改为「备份与恢复」，新增本地备份和恢复功能

---

## 页面结构调整

```
设置
  └─ 备份与恢复（原「WebDAV 远程备份」）
       ├─ 本地备份与恢复（新增）
       │   ├─ [本地备份] → 保存数据库 JSON 到下载文件夹
       │   └─ [本地恢复] → 文件选择器 → 选择恢复方式 → 确认 → 执行
       │
       └─ WebDAV 远程备份（保留现有内容不变）
```

---

## 本地备份

- 调用 `DatabaseManager.instance.dbPath` 获取当前数据文件路径
- 读取文件内容
- 调用 `exportToDownloads()` 相同的下载目录逻辑（`getDownloadsDirectory()`）
- 文件名：`AssetManagement_Backup_2026-06-14_143000.json`
- 成功 Toast：`已备份到下载文件夹: xxx.json`
- 失败提示：明确错误原因

## 本地恢复

- 点击「本地恢复」→ 系统文件选择器（不限定文件类型）
- 选中文件后 → 读取内容 → 解析 JSON → 显示恢复方式选择
- 恢复方式：覆盖 / 合并去重（与 WebDAV 完全一致）
- 二次确认后执行
- 成功 Toast：`已恢复 N 条数据`
- 失败提示：明确错误原因（如「文件格式不正确，无法解析为备份数据」「文件读取失败，请确认文件可访问」等）

---

## 模块架构

```
lib/
  services/
    webdav_service.dart     (已有) WebDAV 备份恢复服务
    local_backup_service.dart (新建) 本地备份恢复服务
  ui/pages/settings/
    backup_settings_page.dart (新建) 统一「备份与恢复」页面，调用两个服务模块
    webdav_settings_page.dart  (保留) WebDAV 子页面（从 backup_settings_page 进入）
```

### LocalBackupService API

```dart
class LocalBackupService {
  /// 备份：将当前数据库复制到下载文件夹
  /// 返回文件路径，失败抛异常
  static Future<String> backupToDownloads();

  /// 恢复：读取备份文件，返回物品列表
  /// [filePath] 用户选择的文件路径
  /// 返回物品列表，失败抛异常（明确说明原因）
  static Future<List<AssetItem>> restoreFromFile(String filePath);
}
```

### 页面结构

```
备份与恢复（backup_settings_page.dart）
  ├─ 本地备份（调用 LocalBackupService.backupToDownloads）
  ├─ 本地恢复（文件选择器 → LocalBackupService.restoreFromFile → 覆盖/合并选择 → 执行）
  │
  └─ WebDAV 远程备份（跳转到原有的 webdav_settings_page.dart）
```

### 恢复流程（本地和 WebDAV 共享）

```
选择文件/备份 → 解析数据 → 选择模式（覆盖/合并）→ 二次确认 → DatabaseManager.replaceAll/mergeDeduplicated
```

---

## 新增依赖

`file_picker: ^8.0.0` — 系统文件选择器

---

## 文件清单

| 文件 | 操作 | 职责 |
|------|------|------|
| `pubspec.yaml` | 添加 | `file_picker` |
| `lib/services/local_backup_service.dart` | 新建 | 本地备份/恢复服务模块 |
| `lib/ui/pages/settings/backup_settings_page.dart` | 新建 | 统一备份恢复页面 |
| `lib/ui/pages/settings/settings_page.dart` | 修改 | 入口改为「备份与恢复」，跳转 backup_settings_page |
| `lib/ui/pages/settings/webdav_settings_page.dart` | 保留 | 从 backup_settings_page 进入的 WebDAV 细节页 |

---

## 验收标准

1. 点击本地备份 → 备份文件保存到下载文件夹
2. 点击本地恢复 → 打开文件选择器
3. 选中备份文件 → 选择覆盖/合并 → 确认后恢复
4. 选非备份文件 → 提示「文件格式不正确」
5. 选不存在/损坏文件 → 提示具体失败原因
6. WebDAV 功能完全不受影响
