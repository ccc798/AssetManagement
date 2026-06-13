import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/translations.dart';
import '../../../data/database/config_dao.dart';

/// 语言设置页面
class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localeCodeProvider);
    // Watch the raw setting to show correct selected state
    final setting = ref.watch(localeSettingProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t('language.title', loc))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOption(context, ref, loc, setting, 'system',
              Icons.settings, theme),
          const SizedBox(height: 8),
          // 动态列出所有已注册的语言
          for (final code in supportedLocales)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildOption(context, ref, loc, setting, code,
                  Icons.language, theme),
            ),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, WidgetRef ref, String loc,
      String setting, String target, IconData icon, ThemeData theme) {
    final isSelected = setting == target;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectLanguage(ref, target),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon,
                  color: isSelected ? theme.colorScheme.primary : Colors.grey),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _label(target, loc),
                  style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  String _label(String target, String loc) {
    switch (target) {
      case 'system': return t('language.system', loc);
      case 'zh': return t('language.chinese', loc);
      case 'en': return t('language.english', loc);
      default: return target; // 新语言暂用代码作为标签
    }
  }

  void _selectLanguage(WidgetRef ref, String target) async {
    // Save to config
    final dao = ConfigDao();
    final config = await dao.getConfig();
    await dao.saveConfig(config.copyWith(locale: target));

    // Update setting provider — localeCodeProvider auto-resolves
    ref.read(localeSettingProvider.notifier).state = target;
  }
}
