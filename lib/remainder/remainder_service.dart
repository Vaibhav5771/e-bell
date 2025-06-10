import 'package:e_bell/remainder/remainder_model.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:typed_data';

import '../alarm/permission_handler.dart';
 // Reuse the existing PermissionHandler

class ReminderService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Schedule a reminder
  static Future<bool> scheduleReminder(ReminderModel reminder) async {
    // Check permissions (reusing existing PermissionHandler)
    bool hasNotificationPermission =
    await PermissionHandler.requestNotificationPermission();
    bool hasExactAlarmPermission =
    await PermissionHandler.requestExactAlarmPermission();

    if (!hasNotificationPermission) {
      print('Notification permission not granted');
      return false;
    }

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Create a notification channel group for reminders
    await androidPlugin?.createNotificationChannelGroup(
      const AndroidNotificationChannelGroup(
        'reminder_group',
        'Reminder Notifications',
      ),
    );

    // Convert startDateTime to TZDateTime
    final tzScheduledTime = tz.TZDateTime.from(reminder.startDateTime, tz.local);

    // Map sound option to raw resource name (without .wav extension)
    String soundFile;
    String normalizedSound = reminder.sound.toLowerCase().trim();
    switch (normalizedSound) {
      case 'beep':
        soundFile = 'beep';
        break;
      case 'chime':
        soundFile = 'chime';
        break;
      case 'opening':
        soundFile = 'opening';
        break;
      case 'radar':
        soundFile = 'radar';
        break;
      default:
        soundFile = 'opening';
        print('Unknown sound: $normalizedSound, falling back to opening');
    }

    // Create a unique channel for this reminder
    final channelId = 'reminder_channel_${reminder.id}';
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        'Reminder ${reminder.id}',
        description: 'Notification for reminder ${reminder.id}',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound(soundFile),
        groupId: 'reminder_group',
      ),
    );

    // Define notification details
    final androidDetails = AndroidNotificationDetails(
    channelId,
    'Reminder ${reminder.id}',
    channelDescription: 'Notification for reminder ${reminder.id}',
    importance: Importance.max,
    priority: Priority.high,
    sound: RawResourceAndroidNotificationSound(soundFile),
    playSound: true,
    enableVibration: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT
    );
    final notificationDetails = NotificationDetails(android: androidDetails);

    try {
    await _notificationsPlugin.zonedSchedule(
    reminder.id,
    reminder.title,
    reminder.description,
    tzScheduledTime,
    notificationDetails,
    androidAllowWhileIdle: hasExactAlarmPermission,
    uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
    );
    print('Scheduled reminder ID: ${reminder.id} at $tzScheduledTime');
    return true;
    } catch (e) {
    print('Error scheduling reminder: $e');
    return false;
    }
  }

  // Cancel a reminder
  static Future<void> cancelReminder(int id) async {
    await _notificationsPlugin.cancel(id);
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.deleteNotificationChannel('reminder_channel_$id');
    print('Cancelled reminder ID: $id');
  }
}