import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:async';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';

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
      final response = await http.get(
        Uri.parse('http://192.168.2.1/intrsong/'),
      ).timeout(const Duration(seconds: 10));

      debugPrint('Raw response: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        debugPrint('Parsed JSON: $jsonData');

        List<String> files = [];

        if (jsonData['Data'] != null && jsonData['Data'] is List) {
          final dataList = jsonData['Data'] as List;

          for (final dataItem in dataList) {
            if (dataItem is Map && dataItem['files'] != null && dataItem['files'] is List) {
              final filesList = dataItem['files'] as List;

              for (final fileEntry in filesList) {
                if (fileEntry is List && fileEntry.isNotEmpty && fileEntry[0] is String) {
                  files.add(fileEntry[0] as String);
                }
              }
            }
          }
        }

        debugPrint('Extracted files: $files');

        setState(() {
          _soundOptions = files;
          _soundOption = files.isNotEmpty ? files[0] : '';
        });

        if (files.isEmpty) {
          debugPrint('No valid files found in response');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No audio files found on device', style: AppTextStyles.body)),
            );
          }
        }
      } else {
        debugPrint('API error: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: ${response.statusCode}', style: AppTextStyles.body)),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}', style: AppTextStyles.body)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  List<String> _extractStringsFromList(List<dynamic> list) {
    return list
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  List<String> _extractStringsFromJsonObject(Map<dynamic, dynamic> json) {
    final List<String> result = [];

    const possibleKeys = ['files', 'allSongs', 'Filenames', 'songs'];

    for (final key in possibleKeys) {
      if (json[key] is List) {
        result.addAll(_extractStringsFromList(json[key]));
      }
    }

    json.values.whereType<List>().forEach((list) {
      result.addAll(_extractStringsFromList(list));
    });

    return result.toSet().toList();
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
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bell sound updated successfully', style: AppTextStyles.body)),
        );
      } else {
        throw Exception('Failed to set bell sound: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error setting bell sound: $e', style: AppTextStyles.body)),
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

    return true;
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
        Uri.parse('http://192.168.2.1/upload/default/$sanitizedFileName'),
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

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _loadUploadedFiles();
        });

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
        title: Text('Permission Permanently Denied', style: AppTextStyles.heading),
        content: Text(
          'Please open app settings and grant permission to access audio files.',
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTextStyles.button.copyWith(color: Colors.black)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: Text('Open Settings', style: AppTextStyles.button.copyWith(color: Colors.black)),
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
        title: Text(title, style: AppTextStyles.heading, textAlign: TextAlign.center),
        content: Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: AppTextStyles.button.copyWith(color: Colors.black)),
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
                    style: AppTextStyles.small.copyWith(color: Colors.grey.shade600),
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
                                child: Text(
                                  sound,
                                  style: AppTextStyles.body,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                              iconSize: 24,
                              dropdownColor: Colors.white,
                              style: AppTextStyles.body,
                              hint: Text('No sounds available', style: AppTextStyles.body),
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
                            : Text('New', style: AppTextStyles.button.copyWith(color: themeProvider.selectedColor)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}