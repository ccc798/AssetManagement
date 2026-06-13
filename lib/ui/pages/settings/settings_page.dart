import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/translations.dart';
import '../../../core/constants/app_constants.dart';
import 'ai_settings_page.dart';
import 'backup_settings_page.dart';
import 'category_management_page.dart';
import 'export_page.dart';
import 'language_settings_page.dart';
import 'theme_settings_page.dart';

/// 设置主页面 — 入口列表，具体设置分别在子页面
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loc2 = ref.read(localeCodeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t('settings.title', loc2))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // AI 智能识别
          Card(
            child: ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.indigo),
              ),
              title: Text(t('ai.title', loc2)),
              subtitle: Text(t('settings.aiSub', loc2)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiSettingsPage()),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 导出数据
          Card(
            child: ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.file_download, color: Colors.teal),
              ),
              title: Text(t('export.title', loc2)),
              subtitle: Text(t('settings.exportSub', loc2)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExportPage()),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 分类管理
          Card(
            child: ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.label, color: Colors.orange),
              ),
              title: Text(t('settings.categories', loc2)),
              subtitle: Text(t('settings.categoriesSub', loc2)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoryManagementPage()),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 主题设置
          Card(
            child: ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.palette, color: Colors.purple),
              ),
              title: Text(t('theme.title', loc2)),
              subtitle: Text(t('settings.themeSub', loc2)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemeSettingsPage()),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 语言
          Card(
            child: ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.language, color: Colors.green),
              ),
              title: Text(t('language.title', loc2)),
              subtitle: Text(t('settings.languageSub', loc2)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LanguageSettingsPage()),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 备份与恢复
          Card(
            child: ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.backup, color: Colors.blue),
              ),
              title: Text(t('backup.title', loc2)),
              subtitle: Text(t('settings.backupSub', loc2)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupSettingsPage()),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 关于
          _buildSectionHeader(theme, t('settings.about', loc2), Icons.info),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Asset Management'),
                  subtitle: Text(t('settings.version', loc2).replaceAll('{ver}', AppConstants.appVersionFull)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(t('settings.techStack', loc2)),
                  subtitle: Text(t('settings.techStackValue', loc2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: Text(t('settings.license', loc2)),
                  subtitle: Text(t('settings.licenseName', loc2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
