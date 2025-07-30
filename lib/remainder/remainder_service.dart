import 'package:http/http.dart' as http;
import 'package:e_bell/remainder/remainder_model.dart';

class ReminderService {
  static const String _baseUrl = 'http://192.168.2.1';

  static String _mapSound(String sound, List<String> availableSounds) {
    // If sound is already a valid file name (e.g., from UI selection), use it
    if (availableSounds.contains(sound)) {
      return sound;
    }
    // Map legacy sound values to the first available sound or a fallback
    switch (sound.toLowerCase()) {
      case 'beep':
      case 'chime':
      case 'opening':
      case 'radar':
        return availableSounds.isNotEmpty ? availableSounds[0] : 'default.mp3';
      default:
        return availableSounds.isNotEmpty ? availableSounds[0] : 'default.mp3';
    }
  }

  static Future<bool> scheduleReminder(ReminderModel reminder, List<String> availableSounds) async {
    try {
      final soundFile = _mapSound(reminder.sound, availableSounds);
      final url = Uri.parse('$_baseUrl/settime/$soundFile');
      final epochTime = (reminder.startDateTime.millisecondsSinceEpoch / 1000).floor().toString();
      final data = '$epochTime,${reminder.isActive ? 1 : 0},0'; // Repeat flag set to 0

      final response = await http.post(
        url,
        body: data,
        headers: {'Content-Type': 'text/plain'},
      );

      if (response.statusCode == 200) {
        print('Scheduled reminder ID: ${reminder.id} on IoT device at $epochTime with sound $soundFile');
        return true;
      } else {
        print('Failed to schedule reminder: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error scheduling reminder on IoT device: $e');
      return false;
    }
  }

  static Future<void> cancelReminder(int id) async {
    try {
      final url = Uri.parse('$_baseUrl/canceltime/$id');
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'text/plain'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('Cancelled reminder ID: $id on IoT device');
      } else {
        print('Failed to cancel reminder: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error canceling reminder on IoT device: $e');
    }
  }
}