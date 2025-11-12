import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';

class ReligiousAlarms extends StatefulWidget {
  const ReligiousAlarms({super.key});
g
  @override
  _ReligiousAlarmsState createState() => _ReligiousAlarmsState();
}

class _ReligiousAlarmsState extends State<ReligiousAlarms> {
  // Religion selection
  List<String> _availableReligions = ['Hinduism', 'Islamic', 'Sikhism', 'Christianity', 'Buddhism', 'Jainism'];
  List<String> _selectedReligions = ['Hinduism', 'Islamic']; // Default selections

  bool _namazEnabled = false;
  bool _sunriseEnabled = false;
  bool _jainEnabled = false;

  // Sound files fetched from IoT device
  List<String> _namazSoundFiles = [];
  List<String> _sunriseSoundFiles = [];
  List<String> _jainSoundFiles = [];

  // Individual sound selection for each namaz
  String _selectedFajrSound = '';
  String _selectedDhuhrSound = '';
  String _selectedAsrSound = '';
  String _selectedMaghribSound = '';
  String _selectedIshaSound = '';
  String _selectedTahajjudSound = '';

  // Individual sound selection for sunrise and sunset
  String _selectedSunriseSound = '';
  String _selectedSunsetSound = '';

  // Individual sound selection for Jain prayers
  String _selectedJainSound1 = '';
  String _selectedJainSound2 = '';
  String _selectedJainSound3 = '';
  String _selectedJainSound4 = '';
  String _selectedJainSound5 = '';

  // Time adjustment variables for sliders
  double _namazOffset = 0.0;
  double _sunriseOffset = 0.0;
  double _jainOffset = 0.0;

  bool _isNamazLoading = false;
  bool _isSunriseLoading = false;
  bool _isJainLoading = false;
  bool _isFetchingSounds = false;
  bool _isUploadingFile = false;

  // Track changes for save buttons
  bool _namazChanged = false;
  bool _sunriseChanged = false;
  bool _jainChanged = false;

  // Store original values to compare changes
  String _originalFajrSound = '';
  String _originalDhuhrSound = '';
  String _originalAsrSound = '';
  String _originalMaghribSound = '';
  String _originalIshaSound = '';
  String _originalTahajjudSound = '';
  double _originalNamazOffset = 0.0;
  String _originalSunriseSound = '';
  String _originalSunsetSound = '';
  double _originalSunriseOffset = 0.0;
  String _originalJainSound1 = '';
  String _originalJainSound2 = '';
  String _originalJainSound3 = '';
  String _originalJainSound4 = '';
  String _originalJainSound5 = '';
  double _originalJainOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchSoundFiles();
    _checkAndSetDefaultOnDevice();
  }

  Future<void> _checkAndSetDefaultOnDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isFirstRun = prefs.getBool('isFirstRun') ?? true;

    if (isFirstRun) {
      if (_selectedReligions.contains('Islamic') && _namazEnabled) {
        await _sendNamazRequest(true);
      }
      if (_selectedReligions.contains('Hinduism') && _sunriseEnabled) {
        await _sendSunriseSunsetRequest(true);
      }
      if (_selectedReligions.contains('Jainism') && _jainEnabled) {
        await _sendJainRequest(true);
      }
      await prefs.setBool('isFirstRun', false);
    }
  }

  // Fetch sound files from IoT device
  Future<void> _fetchSoundFiles() async {
    setState(() => _isFetchingSounds = true);

    try {
      if (_selectedReligions.contains('Islamic')) {
        await _fetchNamazSounds();
      }
      if (_selectedReligions.contains('Hinduism')) {
        await _fetchSunriseSounds();
      }
      if (_selectedReligions.contains('Jainism')) {
        await _fetchJainSounds();
      }
    } catch (e) {
      print('Error fetching sound files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error fetching sound files from device',
              style: AppTextStyles.body,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingSounds = false);
      }
    }
  }

  // Fetch Namaz sound files from IoT device
  Future<void> _fetchNamazSounds() async {
    try {
      final response = await http.get(Uri.parse('http://192.168.2.1/songs'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> filesData = data['Data'][0]['files'];

        setState(() {
          _namazSoundFiles = filesData.map<String>((file) => file[0] as String).toList();

          // Set default selections if available
          if (_namazSoundFiles.isNotEmpty) {
            if (!_namazSoundFiles.contains(_selectedFajrSound)) {
              _selectedFajrSound = _namazSoundFiles[0];
              _originalFajrSound = _selectedFajrSound;
            }
            if (!_namazSoundFiles.contains(_selectedDhuhrSound)) {
              _selectedDhuhrSound = _namazSoundFiles[0];
              _originalDhuhrSound = _selectedDhuhrSound;
            }
            if (!_namazSoundFiles.contains(_selectedAsrSound)) {
              _selectedAsrSound = _namazSoundFiles[0];
              _originalAsrSound = _selectedAsrSound;
            }
            if (!_namazSoundFiles.contains(_selectedMaghribSound)) {
              _selectedMaghribSound = _namazSoundFiles[0];
              _originalMaghribSound = _selectedMaghribSound;
            }
            if (!_namazSoundFiles.contains(_selectedIshaSound)) {
              _selectedIshaSound = _namazSoundFiles[0];
              _originalIshaSound = _selectedIshaSound;
            }
            if (!_namazSoundFiles.contains(_selectedTahajjudSound)) {
              _selectedTahajjudSound = _namazSoundFiles[0];
              _originalTahajjudSound = _selectedTahajjudSound;
            }
          }
        });

        await _saveSettings();
      } else {
        print('Failed to fetch Namaz sounds: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching Namaz sounds: $e');
    }
  }

  // Fetch Jain sound files from IoT device
  Future<void> _fetchJainSounds() async {
    try {
      final response = await http.get(Uri.parse('http://192.168.2.1/songs'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> filesData = data['Data'][0]['files'];

        setState(() {
          _jainSoundFiles = filesData.map<String>((file) => file[0] as String).toList();

          // Set default selections if available
          if (_jainSoundFiles.isNotEmpty) {
            if (!_jainSoundFiles.contains(_selectedJainSound1)) {
              _selectedJainSound1 = _jainSoundFiles[0];
              _originalJainSound1 = _selectedJainSound1;
            }
            if (!_jainSoundFiles.contains(_selectedJainSound2)) {
              _selectedJainSound2 = _jainSoundFiles[0];
              _originalJainSound2 = _selectedJainSound2;
            }
            if (!_jainSoundFiles.contains(_selectedJainSound3)) {
              _selectedJainSound3 = _jainSoundFiles[0];
              _originalJainSound3 = _selectedJainSound3;
            }
            if (!_jainSoundFiles.contains(_selectedJainSound4)) {
              _selectedJainSound4 = _jainSoundFiles[0];
              _originalJainSound4 = _selectedJainSound4;
            }
            if (!_jainSoundFiles.contains(_selectedJainSound5)) {
              _selectedJainSound5 = _jainSoundFiles[0];
              _originalJainSound5 = _selectedJainSound5;
            }
          }
        });

        await _saveSettings();
      } else {
        print('Failed to fetch Jain sounds: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching Jain sounds: $e');
    }
  }

  // Send disable request for Namaz
  Future<void> _sendNamazDisableRequest() async {
    const String url = 'http://192.168.2.1/regctrl/';
    final now = DateTime.now();
    final int year = now.year;
    final int month = now.month;
    final int date = now.day;

    // Default location and timezone values (same as used in _sendNamazRequest)
    double lat = 18.476982;
    double lng = 73.808417;
    const double tz = 5.5;
    final int buffMin = _namazOffset.round();

    final String body = '1,0,$lat,$lng,$tz,$year,$month,$date,$buffMin';

    setState(() => _isNamazLoading = true);

    try {
      final response = await http.post(
        Uri.parse(url),
        body: body,
      );
      if (response.statusCode == 200) {
        print('Namaz disabled successfully: $body');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Namaz disabled',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
      } else {
        print('Failed to disable Namaz: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to disable Namaz: ${response.statusCode}',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error disabling Namaz: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error disabling Namaz',
              style: AppTextStyles.body,
            ),
          ),
        );
      }
    }

    setState(() => _isNamazLoading = false);
  }

  // Send disable request for Sunrise & Sunset
  Future<void> _sendSunriseDisableRequest() async {
    const String url = 'http://192.168.2.1/regctrl/';
    final now = DateTime.now();
    final int year = now.year;
    final int month = now.month;
    final int date = now.day;

    final int buffMin = _sunriseOffset.round();
    double lat = 18.476982;
    double lng = 73.808417;
    const double tz = 5.5;

    final String body = '0,0,$lat,$lng,$tz,$year,$month,$date,$buffMin';

    setState(() => _isSunriseLoading = true);

    try {
      final response = await http.post(
        Uri.parse(url),
        body: body,
      );
      if (response.statusCode == 200) {
        print('Sunrise/Sunset disabled successfully: $body');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sunrise/Sunset disabled',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
      } else {
        print('Failed to disable Sunrise/Sunset: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to disable Sunrise/Sunset: ${response.statusCode}',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error disabling Sunrise/Sunset: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error disabling Sunrise/Sunset',
              style: AppTextStyles.body,
            ),
          ),
        );
      }
    }

    setState(() => _isSunriseLoading = false);
  }

  // Send disable request for Jain
  Future<void> _sendJainDisableRequest() async {
    const String url = 'http://192.168.2.1/regctrl/';
    final now = DateTime.now();
    final int year = now.year;
    final int month = now.month;
    final int date = now.day;

    final int buffMin = _jainOffset.round();
    double lat = 18.476982;
    double lng = 73.808417;
    const double tz = 5.5;

    final String body = '3,0,$lat,$lng,$tz,$year,$month,$date,$buffMin';

    setState(() => _isJainLoading = true);

    try {
      final response = await http.post(
        Uri.parse(url),
        body: body,
      );
      if (response.statusCode == 200) {
        print('Jain prayers disabled successfully: $body');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Jain prayers disabled',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
      } else {
        print('Failed to disable Jain prayers: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to disable Jain prayers: ${response.statusCode}',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error disabling Jain prayers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error disabling Jain prayers',
              style: AppTextStyles.body,
            ),
          ),
        );
      }
    }

    setState(() => _isJainLoading = false);
  }

  // Fetch Sunrise/Sunset sound files from IoT device
  Future<void> _fetchSunriseSounds() async {
    try {
      final response = await http.get(Uri.parse('http://192.168.2.1/songs'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> filesData = data['Data'][0]['files'];

        setState(() {
          _sunriseSoundFiles = filesData.map<String>((file) => file[0] as String).toList();

          // Set default selections if available
          if (_sunriseSoundFiles.isNotEmpty) {
            if (!_sunriseSoundFiles.contains(_selectedSunriseSound)) {
              _selectedSunriseSound = _sunriseSoundFiles[0];
              _originalSunriseSound = _selectedSunriseSound;
            }
            if (!_sunriseSoundFiles.contains(_selectedSunsetSound)) {
              _selectedSunsetSound = _sunriseSoundFiles[0];
              _originalSunsetSound = _selectedSunsetSound;
            }
          }
        });

        await _saveSettings();
      } else {
        print('Failed to fetch Sunrise sounds: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching Sunrise sounds: $e');
    }
  }

  // Load saved settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedReligions = prefs.getStringList('selectedReligions') ?? ['Hinduism', 'Islamic'];
      _namazEnabled = prefs.getBool('namazEnabled') ?? false;
      _sunriseEnabled = prefs.getBool('sunriseEnabled') ?? false;
      _jainEnabled = prefs.getBool('jainEnabled') ?? false;

      // Load selected sounds for each namaz
      _selectedFajrSound = prefs.getString('fajrSound') ?? '';
      _selectedDhuhrSound = prefs.getString('dhuhrSound') ?? '';
      _selectedAsrSound = prefs.getString('asrSound') ?? '';
      _selectedMaghribSound = prefs.getString('maghribSound') ?? '';
      _selectedIshaSound = prefs.getString('ishaSound') ?? '';
      _selectedTahajjudSound = prefs.getString('tahajjudSound') ?? '';

      // Load selected sounds for sunrise and sunset
      _selectedSunriseSound = prefs.getString('sunriseSound') ?? '';
      _selectedSunsetSound = prefs.getString('sunsetSound') ?? '';

      // Load selected sounds for Jain prayers
      _selectedJainSound1 = prefs.getString('jainSound1') ?? '';
      _selectedJainSound2 = prefs.getString('jainSound2') ?? '';
      _selectedJainSound3 = prefs.getString('jainSound3') ?? '';
      _selectedJainSound4 = prefs.getString('jainSound4') ?? '';
      _selectedJainSound5 = prefs.getString('jainSound5') ?? '';

      // Store original values
      _originalFajrSound = _selectedFajrSound;
      _originalDhuhrSound = _selectedDhuhrSound;
      _originalAsrSound = _selectedAsrSound;
      _originalMaghribSound = _selectedMaghribSound;
      _originalIshaSound = _selectedIshaSound;
      _originalTahajjudSound = _selectedTahajjudSound;
      _originalSunriseSound = _selectedSunriseSound;
      _originalSunsetSound = _selectedSunsetSound;
      _originalJainSound1 = _selectedJainSound1;
      _originalJainSound2 = _selectedJainSound2;
      _originalJainSound3 = _selectedJainSound3;
      _originalJainSound4 = _selectedJainSound4;
      _originalJainSound5 = _selectedJainSound5;

      // Load time adjustment values
      _namazOffset = prefs.getDouble('namazOffset') ?? 0.0;
      _sunriseOffset = prefs.getDouble('sunriseOffset') ?? 0.0;
      _jainOffset = prefs.getDouble('jainOffset') ?? 0.0;

      // Store original values
      _originalNamazOffset = _namazOffset;
      _originalSunriseOffset = _sunriseOffset;
      _originalJainOffset = _jainOffset;
    });
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selectedReligions', _selectedReligions);
    await prefs.setBool('namazEnabled', _namazEnabled);
    await prefs.setBool('sunriseEnabled', _sunriseEnabled);
    await prefs.setBool('jainEnabled', _jainEnabled);

    // Save sound selections for each namaz
    await prefs.setString('fajrSound', _selectedFajrSound);
    await prefs.setString('dhuhrSound', _selectedDhuhrSound);
    await prefs.setString('asrSound', _selectedAsrSound);
    await prefs.setString('maghribSound', _selectedMaghribSound);
    await prefs.setString('ishaSound', _selectedIshaSound);
    await prefs.setString('tahajjudSound', _selectedTahajjudSound);

    // Save sound selections for sunrise and sunset
    await prefs.setString('sunriseSound', _selectedSunriseSound);
    await prefs.setString('sunsetSound', _selectedSunsetSound);

    // Save sound selections for Jain prayers
    await prefs.setString('jainSound1', _selectedJainSound1);
    await prefs.setString('jainSound2', _selectedJainSound2);
    await prefs.setString('jainSound3', _selectedJainSound3);
    await prefs.setString('jainSound4', _selectedJainSound4);
    await prefs.setString('jainSound5', _selectedJainSound5);

    // Save time adjustment values
    await prefs.setDouble('namazOffset', _namazOffset);
    await prefs.setDouble('sunriseOffset', _sunriseOffset);
    await prefs.setDouble('jainOffset', _jainOffset);
  }

  // Check if namaz settings have changed
  void _checkNamazChanges() {
    setState(() {
      _namazChanged = (_selectedFajrSound != _originalFajrSound) ||
          (_selectedDhuhrSound != _originalDhuhrSound) ||
          (_selectedAsrSound != _originalAsrSound) ||
          (_selectedMaghribSound != _originalMaghribSound) ||
          (_selectedIshaSound != _originalIshaSound) ||
          (_selectedTahajjudSound != _originalTahajjudSound) ||
          (_namazOffset != _originalNamazOffset);
    });
  }

  // Check if sunrise settings have changed
  void _checkSunriseChanges() {
    setState(() {
      _sunriseChanged = (_selectedSunriseSound != _originalSunriseSound) ||
          (_selectedSunsetSound != _originalSunsetSound) ||
          (_sunriseOffset != _originalSunriseOffset);
    });
  }

  // Check if jain settings have changed
  void _checkJainChanges() {
    setState(() {
      _jainChanged = (_selectedJainSound1 != _originalJainSound1) ||
          (_selectedJainSound2 != _originalJainSound2) ||
          (_selectedJainSound3 != _originalJainSound3) ||
          (_selectedJainSound4 != _originalJainSound4) ||
          (_selectedJainSound5 != _originalJainSound5) ||
          (_jainOffset != _originalJainOffset);
    });
  }

  // Show dialog if location service is disabled
  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Location Service Required",
          style: AppTextStyles.subheading,
        ),
        content: Text(
          "This feature requires location services to determine times. "
              "Please enable location services in your device settings.",
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: AppTextStyles.link,
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: Text(
              "Open Settings",
              style: AppTextStyles.link,
            ),
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
        title: Text(
          "Location Permission Required",
          style: AppTextStyles.subheading,
        ),
        content: Text(
          "This feature needs location permission to determine times. "
              "Please grant this permission in app settings.",
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: AppTextStyles.link,
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: Text(
              "Open Settings",
              style: AppTextStyles.link,
            ),
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
        'latitude': locationData.latitude ?? 18.476982,
        'longitude': locationData.longitude ?? 73.808417,
      };
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error retrieving location',
              style: AppTextStyles.body,
            ),
          ),
        );
      }
      return null;
    }
  }

  // Send POST request to the IoT device for Namaz
  Future<void> _sendNamazRequest(bool enabled) async {
    const String url = 'http://192.168.2.1/regctrl/';
    final now = DateTime.now();
    final int year = now.year;
    final int month = now.month;
    final int date = now.day;

    final int buffMin = _namazOffset.round();
    double lat = 18.476982;
    double lng = 73.808417;
    const double tz = 5.5;

    if (enabled) {
      final location = await _getDeviceLocation();
      if (location != null) {
        lat = location['latitude']!;
        lng = location['longitude']!;
      }
    }

    final String body = '1,${enabled ? 1 : 0},$lat,$lng,$tz,$year,$month,$date,$buffMin';

    setState(() => _isNamazLoading = true);

    try {
      final response = await http.post(
        Uri.parse(url),
        body: body,
      );

      if (response.statusCode == 200) {
        print('Namaz request sent successfully: $body');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Namaz ${enabled ? 'enabled' : 'disabled'} | API: $body',
                style: AppTextStyles.body,
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        // Send sound selection request only when enabling
        if (enabled) {
          await _sendNamazSoundRequest();
        }
      } else {
        print('Failed to send Namaz request: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to send Namaz request: ${response.statusCode} | API: $body',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error sending Namaz request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error sending Namaz request | API: $body',
              style: AppTextStyles.body,
            ),
          ),
        );
      }
    }

    setState(() => _isNamazLoading = false);
  }

  // Send POST request to the IoT device for Sunrise & Sunset (Pooja)
  Future<void> _sendSunriseSunsetRequest(bool enabled) async {
    const String url = 'http://192.168.2.1/regctrl/';
    final now = DateTime.now();
    final int year = now.year;
    final int month = now.month;
    final int date = now.day;

    final int buffMin = _sunriseOffset.round();
    double lat = 18.476982;
    double lng = 73.808417;
    const double tz = 5.5;

    if (enabled) {
      final location = await _getDeviceLocation();
      if (location != null) {
        lat = location['latitude']!;
        lng = location['longitude']!;
      }
    }

    final String body = '2,${enabled ? 1 : 0},$lat,$lng,$tz,$year,$month,$date,$buffMin';

    setState(() => _isSunriseLoading = true);

    try {
      final response = await http.post(
        Uri.parse(url),
        body: body,
      );

      if (response.statusCode == 200) {
        print('Sunrise & Sunset request sent successfully: $body');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sunrise/Sunset ${enabled ? 'enabled' : 'disabled'} | API: $body',
                style: AppTextStyles.body,
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        // Send sound selection request only when enabling
        if (enabled) {
          await _sendSunriseSoundRequest();
        }
      } else {
        print('Failed to send Sunrise & Sunset request: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to send Sunrise & Sunset request: ${response.statusCode} | API: $body',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error sending Sunrise & Sunset request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error sending Sunrise & Sunset request | API: $body',
              style: AppTextStyles.body,
            ),
          ),
        );
      }
    }

    setState(() => _isSunriseLoading = false);
  }

  // Send POST request to the IoT device for Jain Prayers
  Future<void> _sendJainRequest(bool enabled) async {
    const String url = 'http://192.168.2.1/regctrl/';
    final now = DateTime.now();
    final int year = now.year;
    final int month = now.month;
    final int date = now.day;

    final int buffMin = _jainOffset.round();
    double lat = 18.476982;
    double lng = 73.808417;
    const double tz = 5.5;

    if (enabled) {
      final location = await _getDeviceLocation();
      if (location != null) {
        lat = location['latitude']!;
        lng = location['longitude']!;
      }
    }

    final String body = '3,${enabled ? 1 : 0},$lat,$lng,$tz,$year,$month,$date,$buffMin';

    setState(() => _isJainLoading = true);

    try {
      final response = await http.post(
        Uri.parse(url),
        body: body,
      );

      if (response.statusCode == 200) {
        print('Jain prayers request sent successfully: $body');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Jain prayers ${enabled ? 'enabled' : 'disabled'} | API: $body',
                style: AppTextStyles.body,
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        // Send sound selection request only when enabling
        if (enabled) {
          await _sendJainSoundRequest();
        }
      } else {
        print('Failed to send Jain prayers request: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to send Jain prayers request: ${response.statusCode} | API: $body',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error sending Jain prayers request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error sending Jain prayers request | API: $body',
              style: AppTextStyles.body,
            ),
          ),
        );
      }
    }

    setState(() => _isJainLoading = false);
  }

  // Send sound change request for Namaz with individual prayer sounds
  Future<void> _sendNamazSoundRequest() async {
    const String url = 'http://192.168.2.1/regselect/';

    // Create the JSON body for all 6 prayers
    final Map<String, dynamic> requestBody = {
      "1": {
        "1": _selectedFajrSound.isNotEmpty ? _selectedFajrSound : "",
        "2": _selectedDhuhrSound.isNotEmpty ? _selectedDhuhrSound : "",
        "3": _selectedAsrSound.isNotEmpty ? _selectedAsrSound : "",
        "4": _selectedMaghribSound.isNotEmpty ? _selectedMaghribSound : "",
        "5": _selectedIshaSound.isNotEmpty ? _selectedIshaSound : "",
        "6": _selectedTahajjudSound.isNotEmpty ? _selectedTahajjudSound : "",
      }
    };

    setState(() => _isNamazLoading = true);

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        print('Namaz sounds updated successfully');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Namaz sounds updated successfully',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
        await _saveSettings();
      } else {
        print('Failed with status: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update Namaz sounds: ${response.statusCode}',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Connection Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Make sure you're connected to the speaker's Wi-Fi",
              style: AppTextStyles.body,
            ),
          ),
        );
      }
    }

    setState(() => _isNamazLoading = false);
  }

  // Send sound change request for Sunrise & Sunset (Pooja) with individual sounds
  Future<void> _sendSunriseSoundRequest() async {
    const String url = 'http://192.168.2.1/regselect/';

    // Create the JSON body for sunrise and sunset
    final Map<String, dynamic> requestBody = {
      "2": {
        "1": _selectedSunriseSound.isNotEmpty ? _selectedSunriseSound : "",
        "2": _selectedSunsetSound.isNotEmpty ? _selectedSunsetSound : "",
      }
    };

    setState(() => _isSunriseLoading = true);

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        print('Sunrise & Sunset sounds updated successfully');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sunrise & Sunset sounds updated successfully',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
        await _saveSettings();
      } else {
        print('Failed with status: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update Sunrise & Sunset sounds: ${response.statusCode}',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Connection Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Make sure you're connected to the speaker's Wi-Fi",
              style: AppTextStyles.body,
            ),
          ),
        );
      }
    }

    setState(() => _isSunriseLoading = false);
  }

  // Send sound change request for Jain Prayers with individual sounds
  Future<void> _sendJainSoundRequest() async {
    const String url = 'http://192.168.2.1/regselect/';

    // Create the JSON body for Jain prayers (5 songs)
    final Map<String, dynamic> requestBody = {
      "3": {
        "1": _selectedJainSound1.isNotEmpty ? _selectedJainSound1 : "",
        "2": _selectedJainSound2.isNotEmpty ? _selectedJainSound2 : "",
        "3": _selectedJainSound3.isNotEmpty ? _selectedJainSound3 : "",
        "4": _selectedJainSound4.isNotEmpty ? _selectedJainSound4 : "",
        "5": _selectedJainSound5.isNotEmpty ? _selectedJainSound5 : "",
      }
    };

    setState(() => _isJainLoading = true);

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        print('Jain prayers sounds updated successfully');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Jain prayers sounds updated successfully',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
        await _saveSettings();
      } else {
        print('Failed with status: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update Jain prayers sounds: ${response.statusCode}',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Connection Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Make sure you're connected to the speaker's Wi-Fi",
              style: AppTextStyles.body,
            ),
          ),
        );
      }
    }

    setState(() => _isJainLoading = false);
  }

  // Pick audio file from device storage and upload to IoT device
  Future<void> _pickAudioFile(bool isNamaz) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      // Implementation for file upload can be added here if needed
    }
  }

  // Save namaz settings to device
  Future<void> _saveNamazSettings() async {
    if (_namazChanged) {
      setState(() => _isNamazLoading = true);

      // Update the toggle state first
      await _sendNamazRequest(_namazEnabled);

      // Update sounds if changed
      if (_selectedFajrSound != _originalFajrSound ||
          _selectedDhuhrSound != _originalDhuhrSound ||
          _selectedAsrSound != _originalAsrSound ||
          _selectedMaghribSound != _originalMaghribSound ||
          _selectedIshaSound != _originalIshaSound ||
          _selectedTahajjudSound != _originalTahajjudSound) {
        await _sendNamazSoundRequest();
      }

      // Save settings locally
      await _saveSettings();

      // Update original values
      setState(() {
        _originalFajrSound = _selectedFajrSound;
        _originalDhuhrSound = _selectedDhuhrSound;
        _originalAsrSound = _selectedAsrSound;
        _originalMaghribSound = _selectedMaghribSound;
        _originalIshaSound = _selectedIshaSound;
        _originalNamazOffset = _namazOffset;
        _originalTahajjudSound = _selectedTahajjudSound;
        _namazChanged = false;
        _isNamazLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Namaz settings saved to device',
            style: AppTextStyles.body,
          ),
        ),
      );
    }
  }

  // Save sunrise settings to device
  Future<void> _saveSunriseSettings() async {
    if (_sunriseChanged) {
      setState(() => _isSunriseLoading = true);

      // Update the toggle state first
      await _sendSunriseSunsetRequest(_sunriseEnabled);

      // Update sounds if changed
      if (_selectedSunriseSound != _originalSunriseSound ||
          _selectedSunsetSound != _originalSunsetSound) {
        await _sendSunriseSoundRequest();
      }

      // Save settings locally
      await _saveSettings();

      // Update original values
      setState(() {
        _originalSunriseSound = _selectedSunriseSound;
        _originalSunsetSound = _selectedSunsetSound;
        _originalSunriseOffset = _sunriseOffset;
        _sunriseChanged = false;
        _isSunriseLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sunrise settings saved to device',
            style: AppTextStyles.body,
          ),
        ),
      );
    }
  }

  // Save jain settings to device
  Future<void> _saveJainSettings() async {
    if (_jainChanged) {
      setState(() => _isJainLoading = true);

      // Update the toggle state first
      await _sendJainRequest(_jainEnabled);

      // Update sounds if changed
      if (_selectedJainSound1 != _originalJainSound1 ||
          _selectedJainSound2 != _originalJainSound2 ||
          _selectedJainSound3 != _originalJainSound3 ||
          _selectedJainSound4 != _originalJainSound4 ||
          _selectedJainSound5 != _originalJainSound5) {
        await _sendJainSoundRequest();
      }

      // Save settings locally
      await _saveSettings();

      // Update original values
      setState(() {
        _originalJainSound1 = _selectedJainSound1;
        _originalJainSound2 = _selectedJainSound2;
        _originalJainSound3 = _selectedJainSound3;
        _originalJainSound4 = _selectedJainSound4;
        _originalJainSound5 = _selectedJainSound5;
        _originalJainOffset = _jainOffset;
        _jainChanged = false;
        _isJainLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Jain prayers settings saved to device',
            style: AppTextStyles.body,
          ),
        ),
      );
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

  // Show religion selection dialog with immediate updates
  void _showReligionSelectionDialog() {
    // Create a local copy for the dialog state
    List<String> tempSelectedReligions = List.from(_selectedReligions);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white, // Dialog background color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0), // Rounded corners
              ),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      'Select Religions',
                      style: AppTextStyles.subheading.copyWith(
                        color: themeProvider.selectedColor, // Use theme color for title
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Religion checkboxes
                    Container(
                      constraints: BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: ListBody(
                          children: _availableReligions.map((religion) {
                            final bool isEnabled = religion == 'Hinduism' || religion == 'Islamic' || religion == 'Jainism';
                            final bool isSelected = tempSelectedReligions.contains(religion);

                            return Container(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? themeProvider.selectedColor.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: CheckboxListTile(
                                title: Text(
                                  religion,
                                  style: AppTextStyles.body.copyWith(
                                    color: isEnabled ? Colors.black : Colors.grey,
                                  ),
                                ),
                                value: isSelected,
                                onChanged: isEnabled
                                    ? (bool? value) {
                                  setState(() {
                                    if (value != null && value) {
                                      tempSelectedReligions.add(religion);
                                    } else {
                                      tempSelectedReligions.remove(religion);
                                    }
                                  });
                                }
                                    : null,
                                activeColor: themeProvider.selectedColor,
                                checkColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                dense: true,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          child: Text(
                            'Cancel',
                            style: AppTextStyles.link.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        SizedBox(width: 8),
                        TextButton(
                          child: Text(
                            'OK',
                            style: AppTextStyles.link.copyWith(
                              color: themeProvider.selectedColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedReligions = List.from(tempSelectedReligions);
                            });
                            Navigator.of(context).pop();
                            _saveSettings();
                            // Refresh sound files based on selected religions
                            _fetchSoundFiles();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Widget for individual namaz sound selection
  Widget _buildNamazSoundSelection(String namazName, String currentSound, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            namazName,
            style: AppTextStyles.body,
          ),
          _namazSoundFiles.isEmpty
              ? Text(
            'No sounds available',
            style: AppTextStyles.body.copyWith(color: Colors.grey),
          )
              : GestureDetector(
            onTap: () => _showNamazSoundSelection(namazName, currentSound, onChanged),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentSound.isNotEmpty ? currentSound : 'Select sound',
                  style: AppTextStyles.body.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget for individual jain sound selection
  Widget _buildJainSoundSelection(String songName, String currentSound, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            songName,
            style: AppTextStyles.body,
          ),
          _jainSoundFiles.isEmpty
              ? Text(
            'No sounds available',
            style: AppTextStyles.body.copyWith(color: Colors.grey),
          )
              : GestureDetector(
            onTap: () => _showJainSoundSelection(songName, currentSound, onChanged),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentSound.isNotEmpty ? currentSound : 'Select sound',
                  style: AppTextStyles.body.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNamazSoundSelection(String namazName, String currentSound, Function(String?) onChanged) {
    if (_namazSoundFiles.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _buildSoundSelectionSheet(
          title: 'Select Sound for $namazName',
          options: _namazSoundFiles,
          selectedOption: currentSound,
          onSelect: (value) {
            onChanged(value);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showJainSoundSelection(String songName, String currentSound, Function(String?) onChanged) {
    if (_jainSoundFiles.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _buildSoundSelectionSheet(
          title: 'Select Sound for $songName',
          options: _jainSoundFiles,
          selectedOption: currentSound,
          onSelect: (value) {
            onChanged(value);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showSunriseSoundSelection(String eventName, String currentSound, Function(String?) onChanged) {
    if (_sunriseSoundFiles.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _buildSoundSelectionSheet(
          title: 'Select Sound for $eventName',
          options: _sunriseSoundFiles,
          selectedOption: currentSound,
          onSelect: (value) {
            onChanged(value);
            Navigator.pop(context);
          },
        );
      },
    );
  }

// Add this method to build the sound selection sheet (similar to your alarm page)
  Widget _buildSoundSelectionSheet({
    required String title,
    required List<String> options,
    required String selectedOption,
    required Function(String) onSelect,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.7; // 70% of screen height

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: AppTextStyles.subheading.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),

          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey[300],
          ),

          // Sound list
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                return ListTile(
                  title: Text(
                    option,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 16,
                    ),
                  ),
                  trailing: option == selectedOption
                      ? Icon(Icons.check, color: themeProvider.selectedColor, size: 24)
                      : null,
                  onTap: () => onSelect(option),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                );
              },
            ),
          ),

          // Bottom padding
          const SizedBox(height: 8),

          // Safe area for devices with notches
          SizedBox(
            height: MediaQuery.of(context).padding.bottom,
          ),
        ],
      ),
    );
  }

  // Widget for individual sunrise/sunset sound selection
  Widget _buildSunriseSoundSelection(String eventName, String currentSound, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            eventName,
            style: AppTextStyles.body,
          ),
          _sunriseSoundFiles.isEmpty
              ? Text(
            'No sounds available',
            style: AppTextStyles.body.copyWith(color: Colors.grey),
          )
              : GestureDetector(
            onTap: () => _showSunriseSoundSelection(eventName, currentSound, onChanged),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentSound.isNotEmpty ? currentSound : 'Select sound',
                  style: AppTextStyles.body.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
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
        leading: Padding(
          padding: const EdgeInsets.only(left: 5.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: Text(
                'Cancel',
                style: AppTextStyles.link.copyWith(color: themeProvider.selectedColor),
              ),
            ),
          ),
        ),
        title: GestureDetector(
          onTap: _showReligionSelectionDialog,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Astro',
                style: AppTextStyles.heading.copyWith(fontWeight: FontWeight.w500),
              ),
              Icon(Icons.arrow_drop_down, color: themeProvider.selectedColor),
            ],
          ),
        ),
        centerTitle: true, // Added to center the title
        actions: [
          TextButton(
            onPressed: () async {
              await _saveSettings();
              Navigator.pop(context);
            },
            child: Text(
              'Save',
              style: AppTextStyles.link.copyWith(
                color: themeProvider.selectedColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: _isFetchingSounds || _isUploadingFile
          ? Center(child: CircularProgressIndicator(color: themeProvider.selectedColor))
          : Container(
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Namaz Card (only show if Islamic is selected)
            if (_selectedReligions.contains('Islamic')) ...[
              Card(
                color: Colors.grey[50],
                child: Column(
                  children: [
                    // Always visible header with toggle
                    ListTile(
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
                      title: Text(
                        'Namaz',
                        style: AppTextStyles.subheading,
                      ),
                      trailing: Switch(
                        value: _namazEnabled,
                        onChanged: (value) async {
                          setState(() {
                            _namazEnabled = value;
                          });
                          await _saveSettings();
                          _checkNamazChanges();
                          await _sendNamazRequest(value); // Use unified request function
                        },
                        activeColor: themeProvider.selectedColor,
                      ),
                    ),

                    // Collapsible content - only show when enabled
                    if (_namazEnabled) ...[
                      // Individual sound selection for each namaz
                      _buildNamazSoundSelection(
                        'Fajr',
                        _selectedFajrSound,
                            (value) {
                          if (value != null) {
                            setState(() => _selectedFajrSound = value);
                            _checkNamazChanges();
                          }
                        },
                      ),
                      _buildNamazSoundSelection(
                        'Dhuhr',
                        _selectedDhuhrSound,
                            (value) {
                          if (value != null) {
                            setState(() => _selectedDhuhrSound = value);
                            _checkNamazChanges();
                          }
                        },
                      ),
                      _buildNamazSoundSelection(
                        'Asr',
                        _selectedAsrSound,
                            (value) {
                          if (value != null) {
                            setState(() => _selectedAsrSound = value);
                            _checkNamazChanges();
                          }
                        },
                      ),
                      _buildNamazSoundSelection(
                        'Maghrib',
                        _selectedMaghribSound,
                            (value) {
                          if (value != null) {
                            setState(() => _selectedMaghribSound = value);
                            _checkNamazChanges();
                          }
                        },
                      ),
                      _buildNamazSoundSelection(
                        'Isha',
                        _selectedIshaSound,
                            (value) {
                          if (value != null) {
                            setState(() => _selectedIshaSound = value);
                            _checkNamazChanges();
                          }
                        },
                      ),
                      _buildNamazSoundSelection(
                        'Jummah', // Name of the 6th prayer
                        _selectedTahajjudSound,
                            (value) {
                          if (value != null) {
                            setState(() => _selectedTahajjudSound = value);
                            _checkNamazChanges();
                          }
                        },
                      ),

                      // Time Adjustment Slider for Namaz - UPDATED with -30 to +30 range
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time Adjustment',
                              style: AppTextStyles.body,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '-30m',
                                  style: AppTextStyles.body.copyWith(
                                    color: _namazOffset == -30
                                        ? themeProvider.selectedColor
                                        : Colors.grey,
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: _namazOffset,
                                    min: -30,
                                    max: 30,
                                    divisions: 30,
                                    label: '${_namazOffset.round()}m',
                                    onChanged: (value) {
                                      setState(() {
                                        _namazOffset = value;
                                      });
                                      _checkNamazChanges();
                                    },
                                    activeColor: themeProvider.selectedColor,
                                    inactiveColor: Colors.grey[300],
                                  ),
                                ),
                                Text(
                                  '+30m',
                                  style: AppTextStyles.body.copyWith(
                                    color: _namazOffset == 30
                                        ? themeProvider.selectedColor
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            Center(
                              child: Text(
                                '${_namazOffset.round()} minutes',
                                style: AppTextStyles.body.copyWith(
                                  color: themeProvider.selectedColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Save button for Namaz card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: ElevatedButton(
                            onPressed: _namazChanged ? _saveNamazSettings : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _namazChanged
                                  ? themeProvider.selectedColor
                                  : Colors.grey[300],
                              foregroundColor: _namazChanged
                                  ? Colors.white
                                  : Colors.grey[500],
                            ),
                            child: _isNamazLoading
                                ? SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : Text(
                              'Save',
                              style: AppTextStyles.button.copyWith(
                                color: _namazChanged ? Colors.white : Colors.grey[500],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Sunrise & Sunset Card (only show if Hinduism is selected)
            if (_selectedReligions.contains('Hinduism')) ...[
              Card(
                color: Colors.grey[50],
                child: Column(
                  children: [
                    // Always visible header with toggle
                    ListTile(
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
                      title: Text(
                        'Sunrise & Sunset',
                        style: AppTextStyles.subheading,
                      ),
                      trailing: Switch(
                        value: _sunriseEnabled,
                        onChanged: (value) async {
                          setState(() {
                            _sunriseEnabled = value;
                          });
                          await _saveSettings();
                          _checkSunriseChanges();
                          await _sendSunriseSunsetRequest(value); // Use unified request function
                        },
                        activeColor: themeProvider.selectedColor,
                      ),
                    ),

                    // Collapsible content - only show when enabled
                    if (_sunriseEnabled) ...[
                      // Individual sound selection for sunrise and sunset
                      _buildSunriseSoundSelection(
                        'Sunrise',
                        _selectedSunriseSound,
                            (value) {
                          if (value != null) {
                            setState(() => _selectedSunriseSound = value);
                            _checkSunriseChanges();
                          }
                        },
                      ),
                      _buildSunriseSoundSelection(
                        'Sunset',
                        _selectedSunsetSound,
                            (value) {
                          if (value != null) {
                            setState(() => _selectedSunsetSound = value);
                            _checkSunriseChanges();
                          }
                        },
                      ),

                      // Time Adjustment Slider for Sunrise/Sunset - UPDATED with -30 to +30 range
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time Adjustment',
                              style: AppTextStyles.body,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '-30m',
                                  style: AppTextStyles.body.copyWith(
                                    color: _sunriseOffset == -30
                                        ? themeProvider.selectedColor
                                        : Colors.grey,
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: _sunriseOffset,
                                    min: -30,
                                    max: 30,
                                    divisions: 30,
                                    label: '${_sunriseOffset.round()}m',
                                    onChanged: (value) {
                                      setState(() {
                                        _sunriseOffset = value;
                                      });
                                      _checkSunriseChanges();
                                    },
                                    activeColor: themeProvider.selectedColor,
                                    inactiveColor: Colors.grey[300],
                                  ),
                                ),
                                Text(
                                  '+30m',
                                  style: AppTextStyles.body.copyWith(
                                    color: _sunriseOffset == 30
                                        ? themeProvider.selectedColor
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            Center(
                              child: Text(
                                '${_sunriseOffset.round()} minutes',
                                style: AppTextStyles.body.copyWith(
                                  color: themeProvider.selectedColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Save button for Sunrise card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: ElevatedButton(
                            onPressed: _sunriseChanged ? _saveSunriseSettings : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _sunriseChanged
                                  ? themeProvider.selectedColor
                                  : Colors.grey[300],
                              foregroundColor: _sunriseChanged
                                  ? Colors.white
                                  : Colors.grey[500],
                            ),
                            child: _isSunriseLoading
                                ? SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : Text(
                              'Save',
                              style: AppTextStyles.button.copyWith(
                                color: _sunriseChanged ? Colors.white : Colors.grey[500],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Jain Prayers Card (only show if Jainism is selected)
            if (_selectedReligions.contains('Jainism')) ...[
              Card(
                color: Colors.grey[50],
                child: Column(
                  children: [
                    // Always visible header with toggle
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: themeProvider.selectedColor.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.self_improvement, // Using a meditation icon for Jain prayers
                          color: themeProvider.selectedColor,
                          size: 30,
                        ),
                      ),
                      title: Text(
                        'Jain Prayers',
                        style: AppTextStyles.subheading,
                      ),
                      trailing: Switch(
                        value: _jainEnabled,
                        onChanged: (value) async {
                          setState(() {
                            _jainEnabled = value;
                          });
                          await _saveSettings();
                          _checkJainChanges();
                          await _sendJainRequest(value); // Use unified request function
                        },
                        activeColor: themeProvider.selectedColor,
                      ),
                    ),

                    // Collapsible content - only show when enabled
                    if (_jainEnabled) ...[
                      // Individual sound selection for each Jain prayer
                      _buildJainSoundSelection(
                        'Song 1',
                        _selectedJainSound1,
                            (value) {
                          if (value != null) {
                            setState(() => _selectedJainSound1 = value);
                            _checkJainChanges();
                          }
                        },
                      ),
                      _buildJainSoundSelection(
                        'Song 2',
                        _selectedJainSound2,
                            (value) {
                          if (value != null) {
                            setState(() => _selectedJainSound2 = value);
                            _checkJainChanges();
                          }
                        },
                      ),
                      _buildJainSoundSelection(
                        'Song 3',
                        _selectedJainSound3,
                            (value) {
                          if (value != null) {
                            setState(() => _selectedJainSound3 = value);
                            _checkJainChanges();
                          }
                        },
                      ),
                      _buildJainSoundSelection(
                        'Song 4',
                        _selectedJainSound4,
                            (value) {
                          if (value != null) {
                            setState(() => _selectedJainSound4 = value);
                            _checkJainChanges();
                          }
                        },
                      ),
                      _buildJainSoundSelection(
                        'Song 5',
                        _selectedJainSound5,
                            (value) {
                          if (value != null) {
                            setState(() => _selectedJainSound5 = value);
                            _checkJainChanges();
                          }
                        },
                      ),

                      // Time Adjustment Slider for Jain Prayers - UPDATED with -30 to +30 range
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time Adjustment',
                              style: AppTextStyles.body,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '-30m',
                                  style: AppTextStyles.body.copyWith(
                                    color: _jainOffset == -30
                                        ? themeProvider.selectedColor
                                        : Colors.grey,
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: _jainOffset,
                                    min: -30,
                                    max: 30,
                                    divisions: 30,
                                    label: '${_jainOffset.round()}m',
                                    onChanged: (value) {
                                      setState(() {
                                        _jainOffset = value;
                                      });
                                      _checkJainChanges();
                                    },
                                    activeColor: themeProvider.selectedColor,
                                    inactiveColor: Colors.grey[300],
                                  ),
                                ),
                                Text(
                                  '+30m',
                                  style: AppTextStyles.body.copyWith(
                                    color: _jainOffset == 30
                                        ? themeProvider.selectedColor
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            Center(
                              child: Text(
                                '${_jainOffset.round()} minutes',
                                style: AppTextStyles.body.copyWith(
                                  color: themeProvider.selectedColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Save button for Jain card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: ElevatedButton(
                            onPressed: _jainChanged ? _saveJainSettings : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _jainChanged
                                  ? themeProvider.selectedColor
                                  : Colors.grey[300],
                              foregroundColor: _jainChanged
                                  ? Colors.white
                                  : Colors.grey[500],
                            ),
                            child: _isJainLoading
                                ? SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : Text(
                              'Save',
                              style: AppTextStyles.button.copyWith(
                                color: _jainChanged ? Colors.white : Colors.grey[500],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}