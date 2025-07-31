import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderModel {
  final int id;
  final String title;
  final String description;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final bool isImportant;
  final String sound;
  final bool isActive;

  ReminderModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startDateTime,
    required this.endDateTime,
    required this.isImportant,
    required this.sound,
    required this.isActive,
  });

  // Generate a unique 32-bit integer ID
  static Future<int> generateUniqueId() async {
    final prefs = await SharedPreferences.getInstance();
    int nextId = (prefs.getInt('next_reminder_id') ?? 0) + 1;
    if (nextId > 2147483647) nextId = 0; // Reset if exceeding 32-bit max
    await prefs.setInt('next_reminder_id', nextId);
    return nextId;
  }

  // Convert ReminderModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startDateTime': startDateTime.toIso8601String(),
      'endDateTime': endDateTime.toIso8601String(),
      'isImportant': isImportant,
      'sound': sound,
      'isActive': isActive,
    };
  }

  // Create ReminderModel from JSON
  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      startDateTime: DateTime.parse(json['startDateTime']),
      endDateTime: DateTime.parse(json['endDateTime']),
      isImportant: json['isImportant'],
      sound: json['sound'],
      isActive: json['isActive'],
    );
  }
}