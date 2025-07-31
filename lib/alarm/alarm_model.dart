import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmModel {
  final int id;
  final TimeOfDay time;
  final String label;
  final String repeatOption;
  final String sound;
  final bool isSnoozeEnabled;
  final bool isActive;

  AlarmModel({
    required this.id,
    required this.time,
    required this.label,
    required this.repeatOption,
    required this.sound,
    required this.isSnoozeEnabled,
    required this.isActive,
  });

  // Generate a unique 32-bit integer ID
  static Future<int> generateUniqueId() async {
    final prefs = await SharedPreferences.getInstance();
    int nextId = (prefs.getInt('next_alarm_id') ?? 0) + 1;
    if (nextId > 2147483647) nextId = 0; // Reset if exceeding 32-bit max
    await prefs.setInt('next_alarm_id', nextId);
    return nextId;
  }

  // Convert AlarmModel to JSON for SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hour': time.hour,
      'minute': time.minute,
      'label': label,
      'repeatOption': repeatOption,
      'sound': sound,
      'isSnoozeEnabled': isSnoozeEnabled,
      'isActive': isActive,
    };
  }

  // Create AlarmModel from JSON
  factory AlarmModel.fromJson(Map<String, dynamic> json) {
    return AlarmModel(
      id: json['id'],
      time: TimeOfDay(hour: json['hour'], minute: json['minute']),
      label: json['label'],
      repeatOption: json['repeatOption'],
      sound: json['sound'],
      isSnoozeEnabled: json['isSnoozeEnabled'],
      isActive: json['isActive'],
    );
  }
}