import 'package:flutter/material.dart';

class DeviceSettingScreen extends StatelessWidget {
  const DeviceSettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.orange),
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
                    value: 0.5, // Default value for the slider (midpoint)
                    onChanged: (value) {
                      // Handle slider value change if needed
                    },
                    activeColor: Colors.orange,
                    inactiveColor: Colors.grey,
                  ),
                ),
                const Icon(Icons.volume_up, color: Colors.black),
              ],
            ),
            const Divider(height: 32),
            const Text(
              'Name',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Lorem Ipsum',
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