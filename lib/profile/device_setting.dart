import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/theme_state.dart';

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
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("OK"),
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
        title: const Text('Device'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Volume',
              style: TextStyle(color: Colors.grey, fontSize: 14),
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
            const Text(
              'Name',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'E-Bell',
              style: TextStyle(fontSize: 16),
            ),
            const Divider(height: 32),
            const Text(
              'MAC ID',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'bdfs79dtfsfsg8q0f',
              style: TextStyle(fontSize: 16),
            ),
            const Divider(height: 32),
            const Text(
              'IMEI',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'bdfs79dtfsfsg8q0f',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}