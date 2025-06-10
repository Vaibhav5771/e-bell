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

    // Get the Android-specific plugin
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Delete existing channels and group to avoid cached settings
    await androidPlugin?.deleteNotificationChannel('alarm_channel');
    await androidPlugin?.deleteNotificationChannelGroup('alarm_group');

    // Create NotificationChannelGroup
    await androidPlugin?.createNotificationChannelGroup(
      const AndroidNotificationChannelGroup(
        'alarm_group',
        'Alarm Notifications',
      ),
    );
    print('Notification channel group initialized: alarm_group');

    // Create default notification channel
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'alarm_channel',
        'Alarms',
        description: 'Notifications for scheduled alarms',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: null,
        groupId: 'alarm_group',
      ),
    );
    print('Notification channel initialized: alarm_channel');
  }

  // Handle background notification
  static void _onBackgroundNotification(NotificationResponse response) {
    print('Background notification triggered: ${response.payload}');
  }

  // Schedule an alarm
  static Future<bool> scheduleAlarm(AlarmModel alarm) async {
    // Check permissions
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

    // Ensure the NotificationChannelGroup exists
    await androidPlugin?.createNotificationChannelGroup(
      const AndroidNotificationChannelGroup(
        'alarm_group',
        'Alarm Notifications',
      ),
    );

    // Calculate the scheduled time
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final alarmTime = DateTime(
      today.year,
      today.month,
      today.day,
      alarm.time.hour,
      alarm.time.minute,
    );

    final scheduledTime = alarmTime.isBefore(now)
        ? alarmTime.add(const Duration(days: 1))
        : alarmTime;

    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    // Map sound option to raw resource name (without .wav extension)
    String soundFile;
    String normalizedSound = alarm.sound.toLowerCase().trim();
    switch (normalizedSound) {
      case 'beep':
        soundFile = 'beep';
        break;
      case 'chime':
        soundFile = 'chime';
        break;
      case 'radar':
        soundFile = 'radar';
        break;
      case 'opening':
      case 'opening (default)':
        soundFile = 'opening';
        break;
      default:
        soundFile = 'opening';
        print('Unknown sound: $normalizedSound, falling back to opening');
    }
    print(
        'Scheduling alarm ID: ${alarm.id} with sound: $soundFile.wav (from input: ${alarm.sound})');

    // Create a unique channel for this alarm with the custom sound
    final channelId = 'alarm_channel_${alarm.id}';
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        'Alarm ${alarm.id}',
        description: 'Notification for alarm ${alarm.id}',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound(soundFile), // Set sound here
        groupId: 'alarm_group',
      ),
    );

    // Define notification details, including sound for pre-Android 8.0 compatibility
    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Alarm ${alarm.id}',
      channelDescription: 'Notification for alarm ${alarm.id}',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(soundFile), // Set sound here too
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
          'Scheduled alarm ID: ${alarm.id}, Time: $tzScheduledTime, Sound: $soundFile.wav, Channel: $channelId, Exact: $hasExactAlarmPermission');
      return true;
    } catch (e) {
      print('Error scheduling alarm: $e');
      return false;
    }
  }

  // Map repeat option to DateTimeComponents
  static DateTimeComponents? _getDateTimeComponents(String repeatOption) {
    switch (repeatOption.toLowerCase()) {
      case 'every day':
        return DateTimeComponents.time;
      case 'weekdays':
        return DateTimeComponents.dayOfWeekAndTime;
      case 'weekends':
        return DateTimeComponents.dayOfWeekAndTime;
      default:
        return null;
    }
  }

  // Cancel an alarm
  static Future<void> cancelAlarm(int id) async {
    await _notificationsPlugin.cancel(id);
    // Delete the unique channel
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.deleteNotificationChannel('alarm_channel_$id');
    print('Cancelled alarm ID: $id');
  }

  // Test sound immediately
  static Future<void> testSound(String sound) async {
    String soundFile;
    String normalizedSound = sound.toLowerCase().trim();
    switch (normalizedSound) {
      case 'beep':
        soundFile = 'beep'; // Refers to beep.wav
        break;
      case 'chime':
        soundFile = 'chime'; // Refers to chime.wav
        break;
      case 'radar':
        soundFile = 'radar'; // Refers to radar.wav
        break;
      case 'opening':
      case 'opening (default)':
        soundFile = 'opening'; // Refers to opening.wav
        break;
      default:
        soundFile = 'opening'; // Refers to opening.wav
        print('Unknown test sound: $normalizedSound, falling back to opening');
    }
    print('Testing sound: $soundFile.wav (from input: $sound)');

    final androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'Alarms',
      channelDescription: 'Test sound playback',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(soundFile),
      playSound: true,
      enableVibration: false,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    NotificationDetails notificationDetails =
    NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.show(
        999,
        'Test Sound',
        'Playing $soundFile.wav sound',
        notificationDetails,
      );
      print('Test sound $soundFile.wav played successfully');
    } catch (e) {
      print('Error playing test sound: $e');
    }
  }

  // Test immediate scheduled sound
  static Future<void> testImmediateScheduledSound(String sound) async {
    String soundFile;
    String normalizedSound = sound.toLowerCase().trim();
    switch (normalizedSound) {
      case 'beep':
        soundFile = 'beep'; // Refers to beep.wav
        break;
      case 'chime':
        soundFile = 'chime'; // Refers to chime.wav
        break;
      case 'radar':
        soundFile = 'radar'; // Refers to radar.wav
        break;
      case 'opening':
      case 'opening (default)':
        soundFile = 'opening'; // Refers to opening.wav
        break;
      default:
        soundFile = 'opening'; // Refers to opening.wav
        print('Unknown test sound: $normalizedSound, falling back to opening');
    }
    print('Testing immediate scheduled sound: $soundFile.wav (from input: $sound)');

    final androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'Alarms',
      channelDescription: 'Test immediate scheduled sound',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(soundFile),
      playSound: true,
      enableVibration: false,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    NotificationDetails notificationDetails =
    NotificationDetails(android: androidDetails);

    try {
      final now = tz.TZDateTime.now(tz.local);
      await _notificationsPlugin.zonedSchedule(
        998,
        'Test Immediate Scheduled Sound',
        'Playing $soundFile.wav sound',
        now.add(Duration(seconds: 5)),
        notificationDetails,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('Immediate scheduled sound $soundFile.wav scheduled for 5 seconds');
    } catch (e) {
      print('Error scheduling immediate sound: $e');
    }
  }
}