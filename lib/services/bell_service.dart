import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
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
  Future<String?> uploadMp3(BuildContext context, String? filePath,
      bool isWifiConnected) async {
    if (!isWifiConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please connect to IoGen_Speaker Wi-Fi first")),
      );
      return null;
    }

    try {
      String? selectedFilePath = filePath;
      String? fileName;

      // If no filePath is provided, use FilePicker to select a file
      if (selectedFilePath == null) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'wav'],
        );

        if (result == null || result.files.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No file selected")),
          );
          debugPrint("No file selected");
          return null;
        }

        selectedFilePath = result.files.single.path;
        fileName = result.files.single.name;
      } else {
        fileName = selectedFilePath
            .split('/')
            .last;
      }

      if (selectedFilePath == null ||
          (!fileName.toLowerCase().endsWith('.mp3') &&
              !fileName.toLowerCase().endsWith('.wav'))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid audio file selected")),
        );
        debugPrint("Invalid file: $fileName");
        return null;
      }

      final file = File(selectedFilePath);
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Selected file does not exist")),
        );
        debugPrint("File does not exist: $selectedFilePath");
        return null;
      }

      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("File is too large (>10MB)")),
        );
        debugPrint("File too large: $fileSize bytes");
        return null;
      }

      if (!await pingServer()) {
        debugPrint("Server not reachable, proceeding with upload anyway");
      }

      final encodedFileName = Uri.encodeComponent(fileName);
      final uri = 'http://192.168.2.1/upload/$encodedFileName';
      debugPrint("Sending file: $fileName, size: $fileSize bytes to $uri");

      var request = http.MultipartRequest('POST', Uri.parse(uri))
        ..headers['Connection'] = 'keep-alive'
        ..files.add(
            await http.MultipartFile.fromPath('file', selectedFilePath));

      // Show loading SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text("Uploading $fileName..."),
            ],
          ),
          duration: const Duration(seconds: 15), // Slightly longer than 12.84s
        ),
      );

      // Send the request and handle response in background
      request.send().then((streamedResponse) async {
        final response = await http.Response.fromStream(streamedResponse);
        debugPrint("Upload response: ${response.statusCode}, ${response.body}");
        if (response.statusCode == 200) {
          debugPrint("Upload successful: $fileName");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Successfully uploaded $fileName")),
          );
        } else {
          debugPrint("Upload failed: ${response.statusCode}, ${response.body}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
                "Upload failed: ${response.statusCode}, ${response.body}")),
          );
        }
      }).catchError((e) {
        debugPrint("Upload error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload error: $e")),
        );
      });

      // Fallback success SnackBar after 13 seconds
      Future.delayed(const Duration(seconds: 13), () {
        if (ScaffoldMessenger
            .of(context)
            .mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Successfully uploaded $fileName")),
          );
        }
      });

      debugPrint("File sent: $fileName");
      // Copy file to documents directory for persistence
      final directory = await getApplicationDocumentsDirectory();
      final newPath = '${directory.path}/$fileName';
      await file.copy(newPath);
      return newPath; // Return path in documents directory
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading file: $e")),
      );
      debugPrint("Upload error: $e");
      return null;
    }
  }
}