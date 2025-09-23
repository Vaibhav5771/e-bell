import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';

class DeviceSettingScreen extends StatefulWidget {
  const DeviceSettingScreen({super.key});

  @override
  _DeviceSettingScreenState createState() => _DeviceSettingScreenState();
}

class _DeviceSettingScreenState extends State<DeviceSettingScreen> {
  double volume = 50; // Initial volume
  bool isLoading = false;

  Future<void> sendVolume() async {
    String url = 'http://192.168.2.1/setVolume/';

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(url),
        body: volume.toInt().toString(),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Please connect to desired device');
        },
      );

      if (response.statusCode == 200) {
        _showDialog("Success", "Volume set to ${volume.toInt()}");
      } else {
        _showDialog("Error", "Failed with status: ${response.statusCode}");
      }
    } catch (e) {
      _showDialog("Connection Error", e is TimeoutException ? e.message! : "Could not reach device.\nError: $e");
    }

    setState(() => isLoading = false);
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
    print('DeviceSettingScreen: Using color ${themeProvider.selectedColor}');
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    label: volume.toInt().toString(),
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
    );
  }
}