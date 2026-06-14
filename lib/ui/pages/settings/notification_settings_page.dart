import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/translations.dart';
import '../../../data/models/backup_config.dart';
import '../../providers/settings_provider.dart';
import '../../../services/notification_service.dart';
import '../../widgets/app_toast.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends ConsumerState<NotificationSettingsPage> {
  bool _notificationsEnabled = false;
  int _warrantyReminderDays = 7;
  int _lifetimeReminderDays = 30;
  String _reminderTime = '09:00';
  
  final List<String> _timeOptions = [
    '07:00', '08:00', '09:00', '10:00', '11:00', '12:00',
    '13:00', '14:00', '15:00', '16:00', '17:00', '18:00',
    '19:00', '20:00', '21:00', '22:00',
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = ref.read(configProvider).value;
    if (config != null) {
      setState(() {
        _notificationsEnabled = config.notificationsEnabled;
        _warrantyReminderDays = config.warrantyReminderDays;
        _lifetimeReminderDays = config.lifetimeReminderDays;
        _reminderTime = config.reminderTime;
      });
    }
  }

  Future<void> _saveConfig() async {
    final configDao = ref.read(configDaoProvider);
    final configAsync = ref.read(configProvider);
    final config = configAsync.value ?? BackupConfig.default_;
    
    final newConfig = config.copyWith(
      notificationsEnabled: _notificationsEnabled,
      warrantyReminderDays: _warrantyReminderDays,
      lifetimeReminderDays: _lifetimeReminderDays,
      reminderTime: _reminderTime,
    );
    
    await configDao.saveConfig(newConfig);
    ref.invalidate(configProvider);
    
    if (_notificationsEnabled) {
      await NotificationService.instance.requestPermissions();
    }
    
    if (mounted) {
      AppToast.capsule(context, t('toast.saved', ref.read(localeCodeProvider)), Colors.green);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = ref.read(localeCodeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('notification.title', loc)),
        actions: [
          TextButton(
            onPressed: _saveConfig,
            child: Text(t('save', loc)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('notification.enable', loc),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t('notification.enableDesc', loc),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _notificationsEnabled,
                        onChanged: (value) {
                          setState(() {
                            _notificationsEnabled = value;
                          });
                        },
                        activeThumbColor: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('notification.reminderSettings', loc),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildReminderDayOption(
                    icon: Icons.shield,
                    title: t('notification.warrantyReminder', loc),
                    days: _warrantyReminderDays,
                    onChanged: (value) {
                      setState(() {
                        _warrantyReminderDays = value;
                      });
                    },
                    min: 1,
                    max: 30,
                    theme: theme,
                    loc: loc,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildReminderDayOption(
                    icon: Icons.timer,
                    title: t('notification.lifetimeReminder', loc),
                    days: _lifetimeReminderDays,
                    onChanged: (value) {
                      setState(() {
                        _lifetimeReminderDays = value;
                      });
                    },
                    min: 1,
                    max: 90,
                    theme: theme,
                    loc: loc,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTimeSelector(theme, loc),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('notification.about', loc),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('notification.aboutDesc', loc),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderDayOption({
    required IconData icon,
    required String title,
    required int days,
    required ValueChanged<int> onChanged,
    required int min,
    required int max,
    required ThemeData theme,
    required String loc,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: days > min ? () => onChanged(days - 1) : null,
              disabledColor: Colors.grey,
            ),
            SizedBox(
              width: 48,
              child: Text(
                '$days',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: days < max ? () => onChanged(days + 1) : null,
              disabledColor: Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              t('unit.day', loc),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeSelector(ThemeData theme, String loc) {
    return Row(
      children: [
        Icon(Icons.access_time, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            t('notification.reminderTime', loc),
            style: theme.textTheme.bodyLarge,
          ),
        ),
        DropdownButton<String>(
          value: _reminderTime,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _reminderTime = value;
              });
            }
          },
          items: _timeOptions.map((time) {
            return DropdownMenuItem(
              value: time,
              child: Text(time),
            );
          }).toList(),
        ),
      ],
    );
  }
}