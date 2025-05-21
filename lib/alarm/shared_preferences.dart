import 'package:shared_preferences/shared_preferences.dart';
import 'alarm_model.dart';
import 'dart:convert';

class SharedPreferencesService {
  static const String _alarmsKey = 'alarms';

  // Save an alarm
  static Future<void> saveAlarm(AlarmModel alarm) async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = await getAlarms();
    alarms.add(alarm);
    final alarmsJson = alarms.map((alarm) => jsonEncode(alarm.toJson())).toList();
    await prefs.setStringList(_alarmsKey, alarmsJson);
  }

  // Retrieve all alarms
  static Future<List<AlarmModel>> getAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = prefs.getStringList(_alarmsKey) ?? [];
    return alarmsJson
        .map((json) => AlarmModel.fromJson(jsonDecode(json)))
        .toList();
  }

  // Delete an alarm by ID
  static Future<void> deleteAlarm(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = await getAlarms();
    alarms.removeWhere((alarm) => alarm.id == id);
    final alarmsJson = alarms.map((alarm) => jsonEncode(alarm.toJson())).toList();
    await prefs.setStringList(_alarmsKey, alarmsJson);
  }
}