import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class BellService {
  // Singleton pattern
  static final BellService _instance = BellService._internal();

  factory BellService() => _instance;

  BellService._internal();

  /// Pings the bell server to check if it's reachable.
  Future<bool> pingServer() async {
    for (int i = 0; i < 3; i++) {
      try {
        final pingResponse = await http.get(Uri.parse('http://192.168.2.1'))
            .timeout(const Duration(seconds: 3));
        debugPrint("Ping result: ${pingResponse.statusCode}");
        if (pingResponse.statusCode == 200) {
          return true;
        }
      } catch (e) {
        debugPrint("Ping attempt ${i + 1} failed: $e");
      }
    }
    return false;
  }

  /// Fetches uploaded sound files from the IoT device
  Future<List<String>> fetchSoundFiles(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse('http://192.168.2.1/songs')).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request to IoT device timed out');
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final filesData = jsonData['Data'] as List<dynamic>?;

        if (filesData != null && filesData.isNotEmpty) {
          final files = (filesData[0]['files'] as List<dynamic>?)?.map((file) {
            return (file as List<dynamic>)[0] as String;
          }).toList() ?? [];

          debugPrint('Fetched filenames: $files');

          // Filter valid audio files
          final validFiles = files
              .where((file) =>
          !file.contains('/') &&
              (file.toLowerCase().endsWith('.mp3') ||
                  file.toLowerCase().endsWith('.wav')))
              .toList();

          return validFiles;
        } else {
          _showErrorSnackBar(context, 'No sound files found in root directory.');
          return [];
        }
      } else {
        _showErrorSnackBar(context, 'Failed to fetch sounds from device: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _showErrorSnackBar(
          context,
          'Error fetching sounds: Ensure you are connected to the speaker\'s Wi-Fi. Error: $e'
      );
      return [];
    }
  }

  /// Helper method to show error snackbars
  void _showErrorSnackBar(BuildContext context, String message) {
    if (ScaffoldMessenger.of(context).mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Syncs the current time with the bell device.
  Future<bool> setAlarmTime(String mp3File, DateTime alarmTime,
      BuildContext context, String timeFormat) async {
    try {
      if (!await pingServer()) {
        debugPrint("Server not reachable for setting alarm");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server is not reachable")),
        );
        return false;
      }

      final upperMp3File = mp3File.toUpperCase();
      final encodedMp3File = Uri.encodeComponent(upperMp3File);
      final encodedTimeFormat = Uri.encodeComponent(timeFormat);
      final uri = 'http://192.168.2.1/settime/$encodedMp3File/$encodedTimeFormat';
      final headers = {
        'Referer': 'http://192.168.2.1/',
        'Origin': 'http://192.168.2.1',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Connection': 'keep-alive',
      };

      debugPrint(
          "Sending time: $timeFormat (oooooHHoooMM) for $upperMp3File to $uri");
      debugPrint("Request headers: $headers");

      final response = await http.post(
        Uri.parse(uri),
        headers: headers,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('POST request timed out');
      });

      debugPrint("POST Response: ${response.statusCode}, ${response.body}");
      if (response.statusCode == 200) {
        if (response.body.contains('Time set successfully')) {
          return true;
        } else {
          debugPrint("Unexpected response body: ${response.body}");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Alarm set but response unclear")),
          );
          return true; // Assume success if 200
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to set alarm: ${response.statusCode}")),
      );
      return false;
    } catch (e) {
      debugPrint("Set alarm error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error setting alarm: $e")),
      );
      return false;
    }
  }

  Future<void> syncTime(BuildContext context, {required DateTime selectedTime}) async {
    try {
      if (!await pingServer()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server is not reachable")),
        );
        return;
      }

      // Convert selectedTime (assumed in local time) to UTC
      final utcTime = selectedTime.toUtc();
      final epochTime = (utcTime.millisecondsSinceEpoch / 1000).floor().toString();

      debugPrint("Selected time: $selectedTime → UTC: $utcTime → Epoch: $epochTime");

      final response = await http.post(
        Uri.parse('http://192.168.2.1/time/d-'),
        body: epochTime,
        headers: {'Content-Type': 'text/plain'},
      ).timeout(const Duration(seconds: 5));

      debugPrint("Sync time response: ${response.statusCode}, ${response.body}");

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Time synced successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to sync time: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error syncing time: $e")),
      );
      debugPrint("Sync time error: $e");
    }
  }


  /// Uploads an MP3 file to the bell device.
  Future<String?> uploadMp3(
      BuildContext context, String? filePath, bool isWifiConnected) async {
    if (!isWifiConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please connect to IoGen_Speaker Wi-Fi first")),
      );
      return null;
    }

    try {
      String? selectedFilePath = filePath;
      String? fileName;

      // Let user pick a file if not provided
      if (selectedFilePath == null) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'wav'],
        );

        if (result == null || result.files.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No file selected")),
          );
          return null;
        }

        selectedFilePath = result.files.single.path;
        fileName = result.files.single.name;
      } else {
        fileName = selectedFilePath.split('/').last;
      }

      // Validate file
      if (selectedFilePath == null ||
          (!fileName.toLowerCase().endsWith('.mp3') &&
              !fileName.toLowerCase().endsWith('.wav'))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid audio file selected")),
        );
        return null;
      }

      final file = File(selectedFilePath);
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Selected file does not exist")),
        );
        return null;
      }

      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("File is too large (>10MB)")),
        );
        return null;
      }

      if (!await pingServer()) {
        debugPrint("Server not reachable, proceeding with upload anyway");
      }

      final encodedFileName = Uri.encodeComponent(fileName);
      final uri = 'http://192.168.2.1/upload/$encodedFileName';
      debugPrint("Uploading file: $fileName ($fileSize bytes) to $uri");

      // Build the multipart request
      var request = http.MultipartRequest('POST', Uri.parse(uri))
        ..headers['Connection'] = 'keep-alive'
        ..files.add(await http.MultipartFile.fromPath('file', selectedFilePath));

      // Show loader SnackBar (no fixed duration)
      final loaderSnack = ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(days: 1), // keep visible indefinitely
          content: Row(
            children: [
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Text("Uploading $fileName..."),
            ],
          ),
        ),
      );

      // Send upload
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Dismiss loader SnackBar immediately
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      debugPrint("Upload response: ${response.statusCode}, ${response.body}");

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Successfully uploaded $fileName")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Upload failed: ${response.statusCode}")),
        );
      }

      // Copy file to documents directory
      final directory = await getApplicationDocumentsDirectory();
      final newPath = '${directory.path}/$fileName';
      await file.copy(newPath);
      return newPath;
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading file: $e")),
      );
      debugPrint("Upload error: $e");
      return null;
    }
  }
}