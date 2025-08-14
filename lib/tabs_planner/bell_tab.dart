import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:async';
import '../services/theme_state.dart';

class BellTab extends StatefulWidget {
  const BellTab({super.key});

  @override
  State<BellTab> createState() => _BellTabState();
}

class _BellTabState extends State<BellTab> {
  List<String> _soundOptions = [];
  String _soundOption = '';
  bool _isSending = false;
  bool _isUploading = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUploadedFiles();
  }

  Future<void> _loadUploadedFiles() async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(Uri.parse('http://192.168.2.1/intrsong/')).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request to IoT device timed out');
        },
      );

      // Ensure minimum 1-second loading for user feedback
      await Future.delayed(const Duration(seconds: 1));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final alarmData = jsonData['alarmData'] as List<dynamic>?;
        if (alarmData != null && alarmData.isNotEmpty) {
          final filenames = (alarmData[0]['Filenames'] as List<dynamic>?)?.map((file) {
            return (file as List<dynamic>)[0] as String;
          }).toList() ?? [];
          print('Fetched filenames: $filenames');
          setState(() {
            _soundOptions = filenames
                .where((file) =>
            !file.contains('/') &&
                (file.toLowerCase().endsWith('.mp3') ||
                    file.toLowerCase().endsWith('.wav')))
                .toList();
            _soundOption = _soundOptions.isNotEmpty ? _soundOptions[0] : '';
          });
          if (_soundOptions.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('No valid audio files (MP3 or WAV) found in root directory.')),
            );
          }
        } else {
          setState(() {
            _soundOptions = [];
            _soundOption = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No sound files found in root directory.')),
          );
        }
      } else {
        setState(() {
          _soundOptions = [];
          _soundOption = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch sounds from device: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _soundOptions = [];
        _soundOption = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching sounds: Ensure you are connected to the speaker\'s Wi-Fi. Error: $e'),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _setBellSound() async {
    if (_soundOption.isEmpty) {
      _showDialog('Error', 'No sound selected', false);
      return;
    }

    setState(() => _isSending = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.2.1/intrsong/$_soundOption'),
        // Optionally include headers or body if required
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bell sound updated successfully')),
        );
      } else {
        throw Exception('Failed to set bell sound: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error setting bell sound: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _sanitizeFileName(String fileName) {
    String sanitized = fileName
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase();
    if (!sanitized.endsWith('.mp3') && !sanitized.endsWith('.wav')) {
      String ext = fileName.toLowerCase().endsWith('.mp3') ? '.mp3' : '.wav';
      sanitized = '${sanitized.split('.').first}$ext';
    }
    return sanitized;
  }

  Future<bool> _checkAndRequestStoragePermission() async {
    if (Platform.isAndroid) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;

        Map<Permission, PermissionStatus> statuses;

        if (sdkInt >= 33) {
          statuses = await [
            Permission.audio,
          ].request();
          if (!statuses[Permission.audio]!.isGranted) {
            _showPermissionDialog();
            return false;
          }
        } else {
          statuses = await [
            Permission.storage,
          ].request();
          if (!statuses[Permission.storage]!.isGranted) {
            _showPermissionDialog();
            return false;
          }
        }

        return true;
      } catch (e) {
        debugPrint("Error checking/requesting permission: $e");
        return false;
      }
    }

    return true; // Assume granted on non-Android
  }

  Future<void> _uploadSoundFile() async {
    try {
      final hasPermission = await _checkAndRequestStoragePermission();
      if (!hasPermission) return;

      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploading = true);
      final file = result.files.first;

      if (!file.name.toLowerCase().endsWith('.mp3') &&
          !file.name.toLowerCase().endsWith('.wav')) {
        if (!mounted) return;
        _showDialog('Invalid File', 'Please select an MP3 or WAV audio file', false);
        setState(() => _isUploading = false);
        return;
      }

      final sanitizedFileName = _sanitizeFileName(file.name);
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.2.1/uploadintr/$sanitizedFileName'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', file.path!));

      final response = await request.send().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('File upload request timed out');
        },
      );

      if (!mounted) return;

      final body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        setState(() {
          if (!_soundOptions.contains(sanitizedFileName)) {
            _soundOptions.add(sanitizedFileName);
          }
          _soundOption = sanitizedFileName;
        });
        // Refresh the file list after successful upload
        await _loadUploadedFiles();
        _showDialog('Success',
            'File uploaded successfully: $sanitizedFileName\n$body', true);
      } else {
        _showDialog('Upload Failed',
            'Status: ${response.statusCode}\nResponse: $body', false);
      }
    } catch (e) {
      if (mounted) {
        _showDialog('Error', 'File upload failed: $e', false);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Permanently Denied'),
        content: const Text(
          'Please open app settings and grant permission to access audio files.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showDialog(String title, String message, bool isSuccess) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          isSuccess ? Icons.check_circle : Icons.error,
          color: isSuccess ? Colors.green : Colors.red,
          size: 40,
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Card(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT BELL SOUND',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButton<String>(
                              value: _soundOptions.contains(_soundOption)
                                  ? _soundOption
                                  : null,
                              items: _soundOptions
                                  .map((sound) => DropdownMenuItem(
                                value: sound,
                                child: Text(sound),
                              ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _soundOption = value);
                                  _setBellSound();
                                }
                              },
                              isExpanded: true,
                              underline: const SizedBox(),
                              borderRadius: BorderRadius.circular(8),
                              icon: Icon(Icons.arrow_drop_down,
                                  color: themeProvider.textColor),
                              style: Theme.of(context).textTheme.bodyMedium,
                              hint: const Text('No sounds available'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isUploading || isLoading ? null : _uploadSoundFile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: themeProvider.selectedColor,
                          side: BorderSide(color: themeProvider.selectedColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        child: _isUploading
                            ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: themeProvider.selectedColor,
                          ),
                        )
                            : const Text('New'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSending || _soundOption.isEmpty || isLoading
                ? null
                : _setBellSound,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.0),
              ),
              minimumSize: const Size.fromHeight(48),
              backgroundColor: themeProvider.selectedColor,
              foregroundColor: Colors.white,
            ),
            child: _isSending
                ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Applying...'),
              ],
            )
                : const Text('APPLY BELL SOUND'),
          ),
        ],
      ),
    );
  }
}