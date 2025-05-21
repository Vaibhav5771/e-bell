import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:typed_data';
import 'alarm_model.dart';
import 'permission_handler.dart';

class AlarmService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Initialize the notifications plugin
  static Future<void> initialize() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        print('Notification tapped: ${response.payload}');
      },
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotification,
    );

    // Create notification channel without default sound
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
      const AndroidNotificationChannel(
        'alarm_channel',
        'Alarms',
        description: 'Notifications for scheduled alarms',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        // Removed sound: RawResourceAndroidNotificationSound('opening')
      ),
    );
    print('Notification channel initialized for alarm_channel');
  }

  // Handle background notification
  static void _onBackgroundNotification(NotificationResponse response) {
    print('Background notification triggered: ${response.payload}');
  }

  // Schedule an alarm
  static Future<bool> scheduleAlarm(AlarmModel alarm) async {
    // Check exact alarm permission
    bool hasExactAlarmPermission =
    await PermissionHandler.requestExactAlarmPermission();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final alarmTime = DateTime(
      today.year,
      today.month,
      today.day,
      alarm.time.hour,
      alarm.time.minute,
    );

    // If the alarm time is in the past, schedule for tomorrow
    final scheduledTime = alarmTime.isBefore(now)
        ? alarmTime.add(const Duration(days: 1))
        : alarmTime;

    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    // Map sound option to raw resource name (without .mp3 extension)
    String soundFile;
    switch (alarm.sound.toLowerCase()) {
      case 'beep':
        soundFile = 'beep';
        break;
      case 'chime':
        soundFile = 'chime';
        break;
      case 'radar':
        soundFile = 'radar';
        break;
      case 'opening (default)':
      default:
        soundFile = 'opening';
    }

    final androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'Alarms',
      channelDescription: 'Notifications for scheduled alarms',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(soundFile),
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT
    );
    NotificationDetails notificationDetails =
    NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.zonedSchedule(
        alarm.id,
        alarm.label,
        'Alarm triggered!',
        tzScheduledTime,
        notificationDetails,
        androidAllowWhileIdle: hasExactAlarmPermission,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: _getDateTimeComponents(alarm.repeatOption),
      );
      print(
          'Scheduled alarm ID: ${alarm.id}, Time: $tzScheduledTime, Exact: $hasExactAlarmPermission, Sound: $soundFile');
      return true;
    } catch (e) {
      print('Error scheduling alarm: $e');
      return false;
    }
  }

  // Map repeat option to DateTimeComponents
  static DateTimeComponents? _getDateTimeComponents(String repeatOption) {
    switch (repeatOption) {
      case 'Every Day':
        return DateTimeComponents.time;
      case 'Weekdays':
        return DateTimeComponents.dayOfWeekAndTime;
      case 'Weekends':
        return DateTimeComponents.dayOfWeekAndTime;
      default:
        return null;
    }
  }

  // Cancel an alarm
  static Future<void> cancelAlarm(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}