import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class PermissionHandler {
  // Request notification permission
  static Future<bool> requestNotificationPermission() async {
    PermissionStatus status = await Permission.notification.request();
    return status.isGranted;
  }

  // Check if SCHEDULE_EXACT_ALARM is permitted and prompt user if needed
  static Future<bool> requestExactAlarmPermission() async {
    try {
      const platform = MethodChannel('com.example.e_bell/alarm');
      // Check if exact alarms are allowed (Android 12+)
      final bool canScheduleExactAlarms = await platform.invokeMethod('canScheduleExactAlarms');
      if (!canScheduleExactAlarms) {
        // Open system settings to allow exact alarms
        await platform.invokeMethod('requestExactAlarmPermission');
        // Re-check after prompting (with a slight delay to allow settings to update)
        await Future.delayed(const Duration(seconds: 1));
        final bool rechecked = await platform.invokeMethod('canScheduleExactAlarms');
        return rechecked;
      }
      return true;
    } catch (e) {
      print('Error checking exact alarm permission: $e');
      return false;
    }
  }
}