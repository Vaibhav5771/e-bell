import 'package:e_bell/pages/home_page.dart';
import 'package:e_bell/services/qr_screen_page.dart';
import 'package:flutter/material.dart';


class DevicePage extends StatelessWidget {
  const DevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 70),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select device',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 150),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 40,
              mainAxisSpacing: 30,
              children: [
                DeviceCard(
                  label: 'Device 1',
                  icon: _buildDeviceIcon1(),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                ),
                DeviceCard(
                  label: 'Device 2',
                  icon: _buildDeviceIcon2(),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                ),
                DeviceCard(
                  label: 'Device 3',
                  icon: _buildDeviceIcon3(),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                ),
                AddNewDeviceCard(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const QRScannerScreen()), // Reinstated 'const'
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceIcon1() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: 40,
                height: 40,
                color: Colors.teal,
              ),
            ),
          ),
          Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
              ),
            ),
          ),
          Center(
            child: Transform.rotate(
              angle: 45 * 3.14159 / 180,
              child: Container(
                width: 80,
                height: 10,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceIcon2() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.yellow[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.teal,
              ),
            ),
          ),
          Center(
            child: Transform.rotate(
              angle: 45 * 3.14159 / 180,
              child: Container(
                width: 80,
                height: 10,
                color: Colors.blue[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceIcon3() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.yellow[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(60),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green[400],
              ),
            ),
          ),
          Center(
            child: Transform.rotate(
              angle: 45 * 3.14159 / 180,
              child: Container(
                width: 80,
                height: 10,
                color: Colors.blue[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceCard extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  const DeviceCard({super.key, required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: icon,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class AddNewDeviceCard extends StatelessWidget {
  final VoidCallback onTap;

  const AddNewDeviceCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  Icons.add,
                  size: 40,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add new device',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}