import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';
import 'package:intl/intl.dart';

class DeviceSettingScreen extends StatefulWidget {
  const DeviceSettingScreen({super.key});

  @override
  _DeviceSettingScreenState createState() => _DeviceSettingScreenState();
}

class _DeviceSettingScreenState extends State<DeviceSettingScreen> {
  double volume = 50; // Initial volume
  bool isLoading = false;

  String timeSyncMode = 'Automatic';
  int? selectedEpoch;

  Future<void> sendVolume() async {
    String url = 'http://192.168.2.1/setVolume/';

    setState(() => isLoading = true);

    try {
      final response = await http
          .post(
        Uri.parse(url),
        body: volume.toInt().toString(),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Please connect to desired device');
        },
      );

      if (response.statusCode != 200) {
        _showDialog("Error", "Failed with status: ${response.statusCode}");
      }
    } catch (e) {
      _showDialog(
          "Connection Error",
          e is TimeoutException
              ? e.message!
              : "Could not reach device.\nError: $e");
    }

    setState(() => isLoading = false);
  }

  Future<void> sendTime(int epochTime) async {
    String url = 'http://192.168.2.1/time/d-';

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(url),
        body: epochTime.toString(), // Sending epoch as string in body
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Please connect to desired device');
        },
      );

      if (response.statusCode != 200) {
        _showDialog("Error", "Failed with status: ${response.statusCode}");
      } else {
        setState(() {
          selectedEpoch = epochTime;
        });
      }
    } catch (e) {
      _showDialog(
          "Connection Error",
          e is TimeoutException
              ? e.message!
              : "Could not reach device.\nError: $e");
    }

    setState(() => isLoading = false);
  }

  Future<void> pickDateTimeAndSend() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        final epoch = dt.millisecondsSinceEpoch ~/ 1000;
        sendTime(epoch);
      }
    }
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          title,
          style: AppTextStyles.subheading,
        ),
        content: Text(
          content,
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "OK",
              style: AppTextStyles.link,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.selectedColor),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Device',
          style: AppTextStyles.heading,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Volume Section
              Text(
                'Volume',
                style: AppTextStyles.link.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.volume_off, color: Colors.black),
                  Expanded(
                    child: Slider(
                      value: volume,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      onChanged: (value) {
                        setState(() {
                          volume = value;
                        });
                      },
                      onChangeEnd: (value) {
                        sendVolume();
                      },
                      activeColor: themeProvider.selectedColor,
                      inactiveColor: Colors.grey,
                    ),
                  ),
                  const Icon(Icons.volume_up, color: Colors.black),
                ],
              ),
              if (isLoading) ...[
                const SizedBox(height: 8),
                const Center(child: CircularProgressIndicator()),
              ],
              const Divider(height: 32),

              // Time Sync Section
              Text(
                'Time Sync',
                style: AppTextStyles.link.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: timeSyncMode,
                items: ['Automatic', 'Manual']
                    .map((mode) => DropdownMenuItem(
                  value: mode,
                  child: Text(mode),
                ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      timeSyncMode = value;
                    });
                    if (value == 'Automatic') {
                      final epoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                      sendTime(epoch);
                    } else if (value == 'Manual') {
                      pickDateTimeAndSend();
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              if (selectedEpoch != null)
                Text(
                  'Epoch Time: $selectedEpoch',
                  style: AppTextStyles.body,
                ),
              const Divider(height: 32),

              // Device Info Section
              Text(
                'Name',
                style: AppTextStyles.link.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                'E-Bell',
                style: AppTextStyles.body,
              ),
              const Divider(height: 32),
              Text(
                'MAC ID',
                style: AppTextStyles.link.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                'bdfs79dtfsfsg8q0f',
                style: AppTextStyles.body,
              ),
              const Divider(height: 32),
              Text(
                'IMEI',
                style: AppTextStyles.link.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                'bdfs79dtfsfsg8q0f',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}