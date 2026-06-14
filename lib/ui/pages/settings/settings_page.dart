import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/translations.dart';
import '../../../core/services/app_info_service.dart';
import '../../providers/settings_provider.dart';
import 'ai_settings_page.dart';
import 'backup_settings_page.dart';
import 'category_management_page.dart';
import 'data_management_page.dart';
import 'language_settings_page.dart';
import 'notification_settings_page.dart';
import 'theme_settings_page.dart';
import 'version_update_page.dart';

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

          Card(
            child: ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storage, color: Colors.teal),
              ),
              title: Text(t('dataManagement.title', loc2)),
              subtitle: Text(t('settings.dataManagementSub', loc2)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DataManagementPage()),
              ),
            ),
          ),
          const SizedBox(height: 8),

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
          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications, color: Colors.amber),
              ),
              title: Text(t('notification.title', loc2)),
              subtitle: Text(t('notification.subtitle', loc2)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsPage()),
              ),
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader(theme, t('settings.about', loc2), Icons.info),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Asset Management'),
                  subtitle: Text(AppInfoService.version),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VersionUpdatePage()),
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final configAsync = ref.watch(configProvider);
                    return configAsync.when(
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                      data: (config) => SwitchListTile(
                        secondary: const Icon(Icons.network_check),
                        title: Text(t('version.githubProxy', loc2)),
                        subtitle: Text(t('version.githubProxyDesc', loc2)),
                        value: config.githubProxyEnabled,
                        onChanged: (value) async {
                          final newConfig = config.copyWith(githubProxyEnabled: value);
                          await ref.read(configDaoProvider).saveConfig(newConfig);
                          ref.invalidate(configProvider);
                        },
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      ),
                    );
                  },
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