import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class SplashScreen extends StatefulWidget {
  // This line is required for the callback to work
  final Function(bool, String) onConnectionChecked;

  const SplashScreen({super.key, required this.onConnectionChecked});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _checked = false;
  final String targetSsid = "IoGen_Speaker";

  @override
  void initState() {
    super.initState();
    _checkWifiConnection();
  }

  Future<void> _checkWifiConnection() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        String? wifiSSID = await NetworkInfo().getWifiName();
        String? cleanedSSID = wifiSSID?.replaceAll('"', '').trim();
        String normalizedSSID = cleanedSSID?.toLowerCase() ?? '';
        bool isTargetWifi = normalizedSSID == targetSsid.toLowerCase();

        String displaySSID = cleanedSSID ?? 'Unknown';
        String connectionStatus = isTargetWifi
            ? "Connected to $targetSsid"
            : "Connected to Wi-Fi: $displaySSID";

        if (!_checked) {
          _checked = true;
          // Pass the result back to AuthWrapper
          widget.onConnectionChecked(isTargetWifi, connectionStatus);
        }
      } else {
        if (!_checked) {
          _checked = true;
          widget.onConnectionChecked(false, "Not connected to Wi-Fi");
        }
      }
    } catch (e) {
      if (!_checked) {
        _checked = true;
        widget.onConnectionChecked(false, "Error checking Wi-Fi: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Image.asset('assets/appicon.png', height: 200),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 35.0),
              child: Image.asset('assets/iogicon.png', height: 60),
            ),
          ],
        ),
      ),
    );
  }
}