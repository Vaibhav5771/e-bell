import 'package:e_bell/remainder/remainder_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ReminderSharedPreferencesService {
  static const String _remindersKey = 'reminders';

  // Save a reminder
  static Future<void> saveReminder(ReminderModel reminder) async {
    final prefs = await SharedPreferences.getInstance();
    final reminders = await getReminders();
    reminders.add(reminder);
    final remindersJson =
    reminders.map((reminder) => jsonEncode(reminder.toJson())).toList();
    await prefs.setStringList(_remindersKey, remindersJson);
  }

  // Retrieve all reminders
  static Future<List<ReminderModel>> getReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final remindersJson = prefs.getStringList(_remindersKey) ?? [];
    return remindersJson
        .map((json) => ReminderModel.fromJson(jsonDecode(json)))
        .toList();
  }

  // Delete a reminder by ID
  static Future<void> deleteReminder(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final reminders = await getReminders();
    reminders.removeWhere((reminder) => reminder.id == id);
    final remindersJson =
    reminders.map((reminder) => jsonEncode(reminder.toJson())).toList();
    await prefs.setStringList(_remindersKey, remindersJson);
  }
}