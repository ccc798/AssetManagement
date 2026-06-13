# 主题系统设计 v2 — 深浅模式 × 配色方案

**目标：** 支持「明暗模式」×「配色方案」的独立组合选择，所有界面统一响应

**架构：** 
```
数据层 (ConfigDao 存储 themeMode + colorSeed)
    ↓
Provider 层 (组合 themeMode + colorSeed → 生成完整 ThemeData)
    ↓
AppTheme 工厂 (每个 seed 生成 light/dark 两套完整主题)
    ↓
app.dart (MaterialApp 的 theme / darkTheme 分别取 light/dark)
```

---

## 核心组合逻辑

```
用户选择:   明暗模式 = 深色      配色 = 天蓝
              ↓                    ↓
AppTheme.light(seed=蓝色) → 浅色蓝色主题 (用于 theme)
AppTheme.dark(seed=蓝色)  → 深色蓝色主题 (用于 darkTheme)
ThemeMode.dark            → MaterialApp 显示 darkTheme = 深色蓝色主题
```

```
用户选择:   明暗模式 = 浅色      配色 = 靛蓝
              ↓                    ↓
AppTheme.light(seed=靛蓝) → 浅色靛蓝主题 (用于 theme)
ThemeMode.light           → MaterialApp 显示 theme = 浅色靛蓝主题
```

```
用户选择:   明暗模式 = 跟随系统   配色 = 橙色
              ↓                    ↓
AppTheme.light(seed=橙色) → 浅色橙色主题 (用于 theme)
AppTheme.dark(seed=橙色)  → 深色橙色主题 (用于 darkTheme)
ThemeMode.system          → 系统是浅色用 theme，深色用 darkTheme
```

---

## AppTheme 改造

从静态 getter 改为工厂函数：

```dart
class AppTheme {
  /// 根据种子色生成浅色主题
  static ThemeData light(Color seed) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: seed,
    // ... 其余配置不变，依赖 colorSchemeSeed 自动生成色板
  );

  /// 根据种子色生成深色主题
  static ThemeData dark(Color seed) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: seed,
    // ... 其余配置不变
  );
}
```

Material 3 的 `colorSchemeSeed` 会自动从种子色生成完整的 light/dark ColorScheme，无需手动维护每个配色的 light/dark 两套。

---

## 预置色板（8 组）

| 名称 | 种子色 | 浅色预览 | 深色预览 |
|------|--------|----------|----------|
| 靛蓝（默认） | `0xFF5C6BC0` | Indigo 400 | Indigo 200 |
| 天蓝 | `0xFF42A5F5` | Blue 400 | Blue 200 |
| 青绿 | `0xFF26A69A` | Teal 400 | Teal 200 |
| 翠绿 | `0xFF66BB6A` | Green 400 | Green 200 |
| 橙色 | `0xFFFF7043` | Deep Orange 400 | Deep Orange 200 |
| 玫红 | `0xFFEC407A` | Pink 400 | Pink 200 |
| 紫色 | `0xFFAB47BC` | Purple 400 | Purple 200 |
| 红色 | `0xFFEF5350` | Red 400 | Red 200 |

色板仅存种子色（int），Material 3 自动推导完整调色板。

---

## 数据层

### BackupConfig 新增字段

```dart
String themeMode;  // 'system' / 'light' / 'dark'  默认 'system'
int colorSeed;     // 种子色 int 值               默认 0xFF5C6BC0
```

### ConfigDao

```dart
Future<Map<String, dynamic>> getThemeConfig(); // {themeMode, colorSeed}
Future<void> setThemeMode(String mode);
Future<void> setColorSeed(int seed);
```

---

## Provider 层

新建 `lib/ui/providers/theme_provider.dart`：

```dart
/// 初始化: 从 ConfigDao 加载主题配置
final themeConfigProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dao = ConfigDao();
  return dao.getThemeConfig();
});

/// 用户选择的明暗模式
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// 用户选择的种子色
final colorSeedProvider = StateProvider<Color>((ref) => AppColors.primary);

/// 初始化动作 — 从 ConfigDao 读取后设置到 StateProvider
final themeInitProvider = FutureProvider<void>((ref) async {
  final config = await ref.watch(themeConfigProvider.future);
  final mode = config['themeMode'] as String? ?? 'system';
  final seed = config['colorSeed'] as int? ?? 0xFF5C6BC0;
  ref.read(themeModeProvider.notifier).state = _parseThemeMode(mode);
  ref.read(colorSeedProvider.notifier).state = Color(seed);
});

/// 根据当前配置生成完整 ThemeData（提供给 app.dart）
final appThemeProvider = Provider<AppThemePair>((ref) {
  final mode = ref.watch(themeModeProvider);
  final seed = ref.watch(colorSeedProvider);
  return AppThemePair(
    light: AppTheme.light(seed),
    dark: AppTheme.dark(seed),
    mode: mode,
  );
});

class AppThemePair {
  final ThemeData light;
  final ThemeData dark;
  final ThemeMode mode;
  AppThemePair({required this.light, required this.dark, required this.mode});
}
```

---

## app.dart 改造

```dart
class AssetManagementApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 等待初始化完成
    ref.watch(themeInitProvider);

    final themePair = ref.watch(appThemeProvider);

    return MaterialApp(
      theme: themePair.light,
      darkTheme: themePair.dark,
      themeMode: themePair.mode,
      // ...
    );
  }
}
```

---

## UI — ThemeSettingsPage

### 入口
设置页新增「主题」卡片（位于「导出数据」和「WebDAV 备份」之间）

### 页面布局

```
AppBar: 主题设置
────────────────
  明暗模式
  ○ 跟随系统（默认）
  ○ 浅色
  ○ 深色
  ─────────────
  配色方案
  ████ ████ ████ ████
  ████ ████ ████ ████
  (Grid 2x4，圆形色块 + 名称)
  
  实时预览
  ┌────────────────────┐
  │ 预览卡片            │
  │ 主要文字颜色         │
  │ 次要文字颜色         │
  └────────────────────┘
```

- 点选明暗模式即刻生效（通过 provider）
- 点选配色即刻生效（通过 provider）
- 保存到 ConfigDao（在 dispose 时或点击时持久化）
- 预览区域展示当前主题的基本色样

---

## 文件清单

| 文件 | 操作 | 职责 |
|------|------|------|
| `lib/core/theme/app_theme.dart` | 修改 | `light()` / `dark()` 改为接收 seed 参数的工厂函数 |
| `lib/data/models/backup_config.dart` | 修改 | 添加 themeMode/colorSeed 字段 |
| `lib/data/database/config_dao.dart` | 修改 | get/set 主题配置方法 |
| `lib/ui/providers/theme_provider.dart` | 新建 | 主题相关 Provider |
| `lib/ui/pages/settings/theme_settings_page.dart` | 新建 | 主题设置 UI |
| `lib/ui/pages/settings/settings_page.dart` | 修改 | 新增主题入口 |
| `lib/app.dart` | 重写 | ConsumerWidget 读取 provider 动态主题 |

---

## 关键设计决策

1. **深浅模式 × 配色独立选择** — 两者不互相覆盖，通过 `colorSchemeSeed` + `brightness` 独立控制
2. **每套配色自动生成 light/dark** — Material 3 的 `ColorScheme.fromSeed()` 接受 `brightness` 参数，一个 seed 同时输出两套
3. **即时生效无需重启** — Riverpod 响应式链：用户选择 → `StateProvider` 更新 → `Provider` 重新生成 → `MaterialApp` 重建
4. **持久化时机** — 用户选择时即时保存到 ConfigDao（而不是 dispose 时），避免丢失
