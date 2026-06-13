import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/translations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/config_dao.dart';
import '../../providers/theme_provider.dart';

/// 主题设置页面 — 明暗模式 + 配色方案
class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentMode = ref.watch(themeModeProvider);
    final currentSeed = ref.watch(colorSeedProvider);
    final loc2 = ref.read(localeCodeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t('theme.title', loc2))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── 明暗模式 ───
          Text(t('theme.mode', loc2), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildModeCard(context, ref, currentMode, ThemeMode.system, Icons.brightness_auto, t('theme.system', loc2)),
          const SizedBox(height: 8),
          _buildModeCard(context, ref, currentMode, ThemeMode.light, Icons.light_mode, t('theme.light', loc2)),
          const SizedBox(height: 8),
          _buildModeCard(context, ref, currentMode, ThemeMode.dark, Icons.dark_mode, t('theme.dark', loc2)),
          const SizedBox(height: 24),

          // ─── 配色方案 ───
          Text(t('theme.colorScheme', loc2), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: presetColorSchemes.length,
            itemBuilder: (ctx, i) {
              final scheme = presetColorSchemes[i];
              final isSelected = currentSeed.value == scheme.seed.value;
              return GestureDetector(
                onTap: () => _selectColor(ref, scheme.seed),
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.seed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? scheme.seed : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.seed,
                          shape: BoxShape.circle,
                          boxShadow: isSelected
                              ? [BoxShadow(color: scheme.seed.withOpacity(0.5), blurRadius: 8)]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(_colorName(scheme.name, loc2), style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? scheme.seed : null,
                      )),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // ─── 预览 ───
          Text(t('theme.preview', loc2), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildPreviewCard(context, ref, loc2),
        ],
      ),
    );
  }

  Widget _buildModeCard(BuildContext context, WidgetRef ref, ThemeMode current, ThemeMode target, IconData icon, String label) {
    final isSelected = current == target;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectMode(ref, target),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
              const SizedBox(width: 16),
              Expanded(child: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal))),
              if (isSelected) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context, WidgetRef ref, String loc2) {
    final seed = ref.watch(colorSeedProvider);
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
    final previewTheme = isDark ? AppTheme.dark(seed) : AppTheme.light(seed);

    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: previewTheme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('theme.previewCard', loc2), style: previewTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(width: 20, height: 20, decoration: BoxDecoration(
                  color: previewTheme.colorScheme.primary, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(t('theme.primaryColor', loc2), style: TextStyle(color: previewTheme.colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(width: 20, height: 20, decoration: BoxDecoration(
                  color: previewTheme.colorScheme.secondary, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(t('theme.secondaryColor', loc2), style: TextStyle(color: previewTheme.colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: previewTheme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(t('theme.button', loc2), style: TextStyle(color: previewTheme.colorScheme.onPrimary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _colorName(String name, String locale) {
    const map = {
      'indigo': 'color.indigo', 'blue': 'color.blue', 'teal': 'color.teal', 'green': 'color.green',
      'orange': 'color.orange', 'pink': 'color.pink', 'purple': 'color.purple', 'red': 'color.red',
    };
    return t(map[name] ?? 'color.indigo', locale);
  }

  void _selectMode(WidgetRef ref, ThemeMode mode) {
    ref.read(themeModeProvider.notifier).state = mode;
    // 即时持久化
    ConfigDao().setThemeMode(themeModeToString(mode));
  }

  void _selectColor(WidgetRef ref, Color seed) {
    ref.read(colorSeedProvider.notifier).state = seed;
    // 即时持久化
    ConfigDao().setColorSeed(seed.value);
  }
}
