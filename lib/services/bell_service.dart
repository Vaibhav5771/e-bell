import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class BellService {
  // Singleton pattern
  static final BellService _instance = BellService._internal();
  factory BellService() => _instance;
  BellService._internal();

  Future<bool> setAlarmTime(String mp3File, DateTime alarmTime, BuildContext context, String timeFormat) async {
    try {
      if (!await pingServer()) {
        debugPrint("Server not reachable for setting alarm");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server is not reachable")),
        );
        return false;
      }

      // Convert mp3File to uppercase to match HTML logs (e.g., FILE1.MP3)
      final upperMp3File = mp3File.toUpperCase();
      final encodedMp3File = Uri.encodeComponent(upperMp3File);
      final uri = 'http://192.168.2.1/settime/$encodedMp3File';
      final headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': 'http://192.168.2.1/',
        'Origin': 'http://192.168.2.1',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Connection': 'keep-alive',
      };

      debugPrint("Sending time: $timeFormat (24-hour HH:mm) for $upperMp3File to $uri");
      debugPrint("Request headers: $headers");
      debugPrint("Request body: time=$timeFormat");

      final response = await http.post(
        Uri.parse(uri),
        headers: headers,
        body: 'time=$timeFormat',
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

  /// Syncs the current time with the bell device.
  Future<void> syncTime(BuildContext context) async {
    try {
      if (!await pingServer()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server is not reachable")),
        );
        return;
      }

      final now = DateTime.now();
      final timeFormat = DateFormat('MM:dd:yyyy:hh:mm:ss:a').format(now);
      debugPrint("Sending time: $timeFormat");
      int retries = 3;
      for (int i = 0; i < retries; i++) {
        try {
          final response = await http.get(
            Uri.parse('http://192.168.2.1/time/$timeFormat'),
          ).timeout(const Duration(seconds: 5), onTimeout: () {
            throw TimeoutException('Sync time request timed out');
          });
          debugPrint(
              "Sync time response: ${response.statusCode}, ${response.body}");
          if (response.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Time synced successfully")),
            );
            return;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    "Failed to sync time: ${response.statusCode}, ${response.body}"),
              ),
            );
            debugPrint(
                "Sync time failed: ${response.statusCode}, ${response.body}");
          }
          break;
        } catch (e) {
          debugPrint("Sync time retry ${i + 1} failed: $e");
          if (i == retries - 1) throw e;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error syncing time: $e")),
      );
      debugPrint("Sync time error: $e");
    }
  }

  /// Uploads an MP3 file to the bell device.
  Future<void> uploadMp3(BuildContext context, bool isWifiConnected) async {
    if (!isWifiConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please connect to IoGen_Speaker Wi-Fi first")),
      );
      return;
    }

    try {
      // Pick an MP3 file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3'],
      );

      if (result == null || result.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No file selected")),
        );
        debugPrint("No file selected");
        return;
      }

      final filePath = result.files.single.path;
      final fileName = result.files.single.name;
      if (filePath == null || !fileName.toLowerCase().endsWith('.mp3')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid MP3 file selected")),
        );
        debugPrint("Invalid file: $fileName");
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Selected file does not exist")),
        );
        debugPrint("File does not exist: $filePath");
        return;
      }

      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        // Check if file is larger than 10MB
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("File is too large (>10MB)")),
        );
        debugPrint("File too large: $fileSize bytes");
        return;
      }

      if (!await pingServer()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server is not reachable")),
        );
        return;
      }

      final encodedFileName = Uri.encodeComponent(fileName);
      final uri = 'http://192.168.2.1/upload/$encodedFileName';
      debugPrint("Uploading file: $fileName, size: $fileSize bytes to $uri");

      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(uri))
        ..headers['Connection'] = 'keep-alive'
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      // Send request with retries
      int retries = 3;
      for (int i = 0; i < retries; i++) {
        try {
          final streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Upload request timed out'),
          );
          final response = await http.Response.fromStream(streamedResponse);
          debugPrint(
              "Upload response: ${response.statusCode}, ${response.body}");
          if (response.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("File $fileName uploaded successfully")),
            );
            debugPrint("Upload successful: $fileName");
            return;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      "Failed to upload file: ${response.statusCode}, ${response.body}")),
            );
            debugPrint(
                "Upload failed: ${response.statusCode}, ${response.body}");
          }
        } catch (e) {
          debugPrint("Upload retry ${i + 1} failed: $e");
          if (i == retries - 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                  Text("Error uploading file after $retries retries: $e")),
            );
            debugPrint("Upload error after retries: $e");
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading file: $e")),
      );
      debugPrint("Upload error: $e");
    }
  }
}