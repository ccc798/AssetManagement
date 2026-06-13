# 主题系统设计

**目标：** 支持明暗主题切换 + 多色板选择，所有界面统一响应

**架构：** 数据层（ConfigDao 存储主题配置）→ Provider 层（响应式驱动）→ UI 层（设置页 + 实时预览）

**约束：** 不新增第三方包，不改动已有界面代码结构（只通过 Provider 消费主题）

---

## 数据层

### BackupConfig 扩展字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `themeMode` | String | `'system'` | `'system'` / `'light'` / `'dark'` |
| `colorSeed` | int | `0xFF5C6BC0` | 主题色种子（Int 存储，不用 String） |

### ConfigDao 新增方法

```dart
Future<String> getThemeMode();       // 默认 'system'
Future<void> setThemeMode(String m);
Future<int> getColorSeed();           // 默认 0xFF5C6BC0
Future<void> setColorSeed(int seed);
```

---

## Provider 层

### `lib/ui/providers/theme_provider.dart`

```dart
/// 用户选择的主题模式
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// 用户选择的主题色种子
final colorSeedProvider = StateProvider<Color>((ref) => AppColors.primary);

/// 初始化时从 ConfigDao 加载
final themeInitProvider = FutureProvider<void>((ref) async { ... });

/// 动态生成的 AppTheme（watch themeModeProvider + colorSeedProvider）
final appThemeProvider = Provider<ThemeData>((ref) {
  final mode = ref.watch(themeModeProvider);
  final seed = ref.watch(colorSeedProvider);
  final isDark = mode == ThemeMode.dark ||
      (mode == ThemeMode.system && ...);
  return _buildTheme(seed, isDark);
});
```

由于 `ThemeMode.system` 需要知道系统当前是否为暗色，通过 `MediaQuery.platformBrightness` 或 `WidgetsBinding.instance.platformDispatcher.platformBrightness` 获取。

---

## 预置色板

每组提供种子色 + 展示名称：

| 名称 | 种子色 | 效果预览 |
|------|--------|----------|
| 靛蓝（默认） | `0xFF5C6BC0` | 当前 Indigo 配色 |
| 天蓝 | `0xFF42A5F5` | 清爽蓝色系 |
| 青绿 | `0xFF26A69A` | Teal 系 |
| 翠绿 | `0xFF66BB6A` | 绿色自然系 |
| 橙色 | `0xFFFF7043` | 暖色活力系 |
| 玫红 | `0xFFEC407A` | Pink 系 |
| 紫色 | `0xFFAB47BC` | 优雅紫色系 |
| 红色 | `0xFFEF5350` | 热情红色系 |

---

## UI 层

### 设置页入口

设置页新增「主题」Section（位于「导出数据」下方，「WebDAV 备份」上方）：

```
🎨 主题设置
  切换明暗主题和配色
```

### ThemeSettingsPage

- **明暗模式**: Radio 三选一（跟随系统 / 浅色 / 深色），点选即时生效
- **配色方案**: GridView 色板选择器，每个色块显示圆形色样 + 名称，选中高亮
- 底部可实时预览效果（一个 Card 显示当前主题的基本色样）

---

## 文件清单

| 文件 | 操作 | 职责 |
|------|------|------|
| `lib/data/models/backup_config.dart` | 修改 | 添加 themeMode/colorSeed 字段 |
| `lib/data/database/config_dao.dart` | 修改 | 添加 get/set 主题方法 |
| `lib/ui/providers/theme_provider.dart` | 新建 | 主题相关 Provider |
| `lib/ui/pages/settings/theme_settings_page.dart` | 新建 | 主题设置 UI |
| `lib/ui/pages/settings/settings_page.dart` | 修改 | 新增入口 |
| `lib/app.dart` | 修改 | 改为读取 provider 动态主题 |
| `lib/main.dart` | 修改 | 启动时初始化主题配置 |

---

## 关键设计决策

1. **颜色存 int 而非 String** — 避免序列化/反序列化开销
2. **主题色通过 colorSeed 驱动** — Material 3 自动生成完整调色板，无需手动维护明暗两套
3. **ThemeMode.system 实时跟随** — 通过监听 `platformBrightness` 变化，不需要重启
4. **Data 层只存原始值** — Provider 层负责转换为 Flutter 类型
5. **配置变更即时生效** — 通过 Riverpod 的响应式链自动重建 UI
