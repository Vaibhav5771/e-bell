import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/theme_state.dart';

class ReligiousAlarms extends StatefulWidget {
  const ReligiousAlarms({super.key});

  @override
  _ReligiousAlarmsState createState() => _ReligiousAlarmsState();
}

class _ReligiousAlarmsState extends State<ReligiousAlarms> {
  bool _namazEnabled = true;
  bool _sunriseEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load saved settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _namazEnabled = prefs.getBool('namazEnabled') ?? true;
      _sunriseEnabled = prefs.getBool('sunriseEnabled') ?? true;
    });
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('namazEnabled', _namazEnabled);
    await prefs.setBool('sunriseEnabled', _sunriseEnabled);
  }

  // Show dialog if location service is disabled
  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Location Service Required"),
        content: const Text(
          "Namaz settings require location services to determine prayer times. "
              "Please enable location services in your device settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  // Show dialog if location permission is denied
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Location Permission Required"),
        content: const Text(
          "Namaz settings need location permission to determine prayer times. "
              "Please grant this permission in app settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  // Get device location
  Future<Map<String, double>?> _getDeviceLocation() async {
    Location location = Location();
    try {
      // Check if location service is enabled
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            _showLocationServiceDialog();
          }
          return null;
        }
      }

      // Check location permission
      var status = await Permission.location.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        status = await Permission.location.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          if (mounted) {
            _showPermissionDialog();
          }
          return null;
        }
      }

      // Get location
      LocationData locationData = await location.getLocation();
      return {
        'latitude': locationData.latitude ?? 18.520,
        'longitude': locationData.longitude ?? 73.8567,
      };
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error retrieving location')),
        );
      }
      return null;
    }
  }

  // Send POST request to the IoT device
  Future<void> _sendNamazRequest(bool enabled) async {
    const String url = 'http://192.168.2.1/namaz/';
    // Use current date
    final now = DateTime.now();
    final int year = now.year;
    final int month = now.month;
    final int day = now.day;
    // Default coordinates
    double lat = 18.520;
    double lng = 73.8567;
    const double tz = 5.3; // Timezone remains hardcoded

    // Only fetch location if enabling Namaz
    if (enabled) {
      final location = await _getDeviceLocation();
      if (location != null) {
        lat = location['latitude']!;
        lng = location['longitude']!;
      }
    }

    final String body = enabled
        ? '1,$lat,$lng,$tz,$year,$month,$day' // Activation = 1 for enabled
        : '0,$lat,$lng,$tz,$year,$month,$day'; // Activation = 0 for disabled

    try {
      final response = await http.post(
        Uri.parse(url),
        body: body,
      );

      if (response.statusCode == 200) {
        print('Namaz request sent successfully: $body');
      } else {
        print('Failed to send Namaz request: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send Namaz request: ${response.statusCode}'),
            ),
          );
        }
      }
    } catch (e) {
      print('Error sending Namaz request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error sending Namaz request'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    print('ReligiousAlarms: Using color ${themeProvider.selectedColor}');
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 5.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: Text(
                'Cancel',
                style: TextStyle(color: themeProvider.selectedColor, fontSize: 16),
              ),
            ),
          ),
        ),
        title: const Center(
          child: Text(
            'Regional Calendar',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _saveSettings();
              Navigator.pop(context);
            },
            child: Text(
              'Save',
              style: TextStyle(
                color: themeProvider.selectedColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Container(
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              color: Colors.grey[50],
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: themeProvider.selectedColor.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset(
                    'assets/namaz_icon.svg',
                    colorFilter: ColorFilter.mode(
                      themeProvider.selectedColor,
                      BlendMode.srcIn,
                    ),
                    height: 30,
                    width: 30,
                  ),
                ),
                title: const Text('Namaz'),
                subtitle: const Text(
                  'Namaz is the Islamic practice of performing ritual prayers five times a day as an act of worship and devotion to Allah',
                ),
                trailing: Switch(
                  value: _namazEnabled,
                  onChanged: (value) async {
                    setState(() {
                      _namazEnabled = value;
                    });
                    await _sendNamazRequest(value); // Send POST request with dynamic location
                    await _saveSettings(); // Save the setting immediately
                  },
                  activeColor: themeProvider.selectedColor,
                ),
              ),
            ),
            Card(
              color: Colors.grey[50],
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: themeProvider.selectedColor.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wb_sunny,
                    color: themeProvider.selectedColor,
                    size: 30,
                  ),
                ),
                title: const Text('Sunrise & Sunset'),
                subtitle: const Text(
                  'Set a daily reminder for sunrise and sunset to observe Jain spiritual practices and mindful living.',
                ),
                trailing: Switch(
                  value: _sunriseEnabled,
                  onChanged: (value) async {
                    setState(() {
                      _sunriseEnabled = value;
                    });
                    await _saveSettings(); // Save the setting immediately
                  },
                  activeColor: themeProvider.selectedColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}