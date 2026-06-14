import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../../../data/models/asset_item.dart';
import '../../../data/models/backup_config.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings);
    
    await _notificationsPlugin.initialize(initializationSettings);
    _initialized = true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'asset_management_channel',
      '资产管理提醒',
      channelDescription: '物品保修到期、生命周期结束等提醒',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    );
    
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<void> scheduleDailyReminder(
    int id,
    String title,
    String body,
    String time,
  ) async {
    await initialize();
    
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    
    final scheduledTime = tz.TZDateTime(
      tz.local,
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      hour,
      minute,
    );
    
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduledTime.add(const Duration(days: 1));
    }
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'asset_management_channel',
      '资产管理提醒',
      channelDescription: '每日定时提醒',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.periodicallyShow(
      id,
      title,
      body,
      RepeatInterval.daily,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> checkAndNotifyExpiringItems(
    List<AssetItem> items,
    BackupConfig config,
  ) async {
    if (!config.notificationsEnabled) return;
    
    await initialize();
    
    final now = DateTime.now();
    final expiringItems = <AssetItem, String>{};
    
    for (final item in items) {
      if (item.isArchived || item.isDeleted) continue;
      
      if (item.warrantyExpiry != null) {
        final daysUntilExpiry = item.warrantyExpiry!.difference(now).inDays;
        if (daysUntilExpiry >= 0 && daysUntilExpiry <= config.warrantyReminderDays) {
          expiringItems[item] = 'warranty';
        }
      }
      
      if (item.estimatedEndDate != null) {
        final daysUntilEnd = item.estimatedEndDate!.difference(now).inDays;
        if (daysUntilEnd >= 0 && daysUntilEnd <= config.lifetimeReminderDays) {
          expiringItems[item] = 'lifetime';
        }
      }
    }
    
    if (expiringItems.isEmpty) return;
    
    String title;
    String body;
    
    if (expiringItems.length == 1) {
      final item = expiringItems.keys.first;
      final type = expiringItems[item];
      
      if (type == 'warranty') {
        title = '保修即将到期';
        final days = item.warrantyExpiry!.difference(now).inDays;
        body = '${item.name} 的保修将在 ${days == 0 ? '今天' : '$days 天后'}到期';
      } else {
        title = '物品即将淘汰';
        final days = item.estimatedEndDate!.difference(now).inDays;
        body = '${item.name} 预计将在 ${days == 0 ? '今天' : '$days 天后'}达到使用期限';
      }
      
      await showNotification(
        id: item.id,
        title: title,
        body: body,
        payload: 'item_${item.id}',
      );
    } else {
      title = '资产管理提醒';
      final warrantyCount = expiringItems.values.where((t) => t == 'warranty').length;
      final lifetimeCount = expiringItems.values.where((t) => t == 'lifetime').length;
      
      body = '有 ';
      if (warrantyCount > 0) {
        body += '$warrantyCount 件物品保修即将到期';
      }
      if (warrantyCount > 0 && lifetimeCount > 0) {
        body += '，';
      }
      if (lifetimeCount > 0) {
        body += '$lifetimeCount 件物品即将达到使用期限';
      }
      
      await showNotification(
        id: 999,
        title: title,
        body: body,
        payload: 'expiring_summary',
      );
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<bool> requestPermissions() async {
    await initialize();
    return await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission() ?? false;
  }
}