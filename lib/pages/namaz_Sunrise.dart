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
import '../services/theme_state.dart';

class ReligiousAlarms extends StatefulWidget {
  const ReligiousAlarms({super.key});

  @override
  _ReligiousAlarmsState createState() => _ReligiousAlarmsState();
}

class _ReligiousAlarmsState extends State<ReligiousAlarms> {
  bool _namazEnabled = true;
  bool _sunriseEnabled = true;

  // Sound files fetched from IoT device
  List<String> _namazSoundFiles = [];
  List<String> _sunriseSoundFiles = [];

  String _selectedNamazSound = '';
  String _selectedSunriseSound = '';

  // Time adjustment variables for sliders
  double _namazOffset = 0.0;
  double _sunriseOffset = 0.0;

  bool _isNamazLoading = false;
  bool _isSunriseLoading = false;
  bool _isFetchingSounds = false;
  bool _isUploadingFile = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchSoundFiles();
  }

  // Fetch sound files from IoT device
  Future<void> _fetchSoundFiles() async {
    setState(() => _isFetchingSounds = true);

    try {
      await _fetchNamazSounds();
      await _fetchSunriseSounds();
    } catch (e) {
      print('Error fetching sound files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error fetching sound files from device')),
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
      final response = await http.get(Uri.parse('http://192.168.2.1/namaz'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> filesData = data['Data'][0]['files'];

        setState(() {
          _namazSoundFiles = filesData.map<String>((file) => file[0] as String).toList();

          // Set default selection if available
          if (_namazSoundFiles.isNotEmpty && !_namazSoundFiles.contains(_selectedNamazSound)) {
            _selectedNamazSound = _namazSoundFiles[0];
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

  // Fetch Sunrise/Sunset sound files from IoT device
  Future<void> _fetchSunriseSounds() async {
    try {
      final response = await http.get(Uri.parse('http://192.168.2.1/pooja'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> filesData = data['Data'][0]['files'];

        setState(() {
          _sunriseSoundFiles = filesData.map<String>((file) => file[0] as String).toList();

          // Set default selection if available
          if (_sunriseSoundFiles.isNotEmpty && !_sunriseSoundFiles.contains(_selectedSunriseSound)) {
            _selectedSunriseSound = _sunriseSoundFiles[0];
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
      _namazEnabled = prefs.getBool('namazEnabled') ?? true;
      _sunriseEnabled = prefs.getBool('sunriseEnabled') ?? true;

      // Load selected sounds
      _selectedNamazSound = prefs.getString('namazSound') ?? '';
      _selectedSunriseSound = prefs.getString('sunriseSound') ?? '';

      // Load time adjustment values
      _namazOffset = prefs.getDouble('namazOffset') ?? 0.0;
      _sunriseOffset = prefs.getDouble('sunriseOffset') ?? 0.0;
    });
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('namazEnabled', _namazEnabled);
    await prefs.setBool('sunriseEnabled', _sunriseEnabled);
    await prefs.setString('namazSound', _selectedNamazSound);
    await prefs.setString('sunriseSound', _selectedSunriseSound);

    // Save time adjustment values
    await prefs.setDouble('namazOffset', _namazOffset);
    await prefs.setDouble('sunriseOffset', _sunriseOffset);
  }

  // Show dialog if location service is disabled
  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Location Service Required"),
        content: const Text(
          "This feature requires location services to determine times. "
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
          "This feature needs location permission to determine times. "
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
        'latitude': locationData.latitude ?? 18.476982,
        'longitude': locationData.longitude ?? 73.808417,
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

// Send POST request to the IoT device for Namaz
  Future<void> _sendNamazRequest(bool enabled) async {
    const String url = 'http://192.168.2.1/regctrl/';
    final now = DateTime.now();
    final int year = now.year;
    final int month = now.month;
    final int date = now.day;

    // Convert slider value to minutes for buff_min (direct minute value)
    final int buffMin = _namazOffset.round();

    double lat = 18.476982;
    double lng = 73.808417;
    const double tz = 5.5; // Updated timezone from log

    if (enabled) {
      final location = await _getDeviceLocation();
      if (location != null) {
        lat = location['latitude']!;
        lng = location['longitude']!;
      }
    }

    final String body = '1,${enabled ? 1 : 0},$lat,$lng,$tz,$year,$month,$date,$buffMin';

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
              content: Text('Namaz ${enabled ? 'enabled' : 'disabled'} | API: $body'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        // Send sound selection request
        await _sendNamazSoundRequest();
      } else {
        print('Failed to send Namaz request: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send Namaz request: ${response.statusCode} | API: $body'),
            ),
          );
        }
      }
    } catch (e) {
      print('Error sending Namaz request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending Namaz request | API: $body'),
          ),
        );
      }
    }
  }
  // Send POST request to the IoT device for Sunrise & Sunset (Pooja)
  Future<void> _sendSunriseSunsetRequest(bool enabled) async {
    const String url = 'http://192.168.2.1/regctrl/';
    final now = DateTime.now();
    final int year = now.year;
    final int month = now.month;
    final int date = now.day;

    // Convert slider value to minutes for buff_min (direct minute value)
    final int buffMin = _sunriseOffset.round();

    double lat = 18.476982;
    double lng = 73.808417;
    const double tz = 5.5; // Updated timezone from log

    if (enabled) {
      final location = await _getDeviceLocation();
      if (location != null) {
        lat = location['latitude']!;
        lng = location['longitude']!;
      }
    }

    final String body = '0,${enabled ? 1 : 0},$lat,$lng,$tz,$year,$month,$date,$buffMin';

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
              content: Text('Sunrise/Sunset ${enabled ? 'enabled' : 'disabled'} | API: $body'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        // Send sound selection request
        await _sendSunriseSoundRequest();
      } else {
        print('Failed to send Sunrise & Sunset request: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send Sunrise & Sunset request: ${response.statusCode} | API: $body'),
            ),
          );
        }
      }
    } catch (e) {
      print('Error sending Sunrise & Sunset request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending Sunrise & Sunset request | API: $body'),
          ),
        );
      }
    }
  }

  // Send sound change request for Namaz
  Future<void> _sendNamazSoundRequest() async {
    const String url = 'http://192.168.2.1/regselect/';
    final String fileName = _selectedNamazSound;

    if (fileName.isEmpty) return;

    setState(() => _isNamazLoading = true);

    try {
      final response = await http.post(
        Uri.parse(url),
        body: '1,$fileName',
      );
      if (response.statusCode == 200) {
        _showDialog("Success", "Namaz sound changed to $fileName");
        await _saveSettings();
      } else {
        _showDialog("Error", "Failed with status: ${response.statusCode}");
      }
    } catch (e) {
      _showDialog("Connection Error", "Make sure you're connected to the speaker's Wi-Fi.\n\nError: $e");
    }

    setState(() => _isNamazLoading = false);
  }

  // Send sound change request for Sunrise & Sunset (Pooja)
  Future<void> _sendSunriseSoundRequest() async {
    const String url = 'http://192.168.2.1/regselect/';
    final String fileName = _selectedSunriseSound;

    if (fileName.isEmpty) return;

    setState(() => _isSunriseLoading = true);

    try {
      final response = await http.post(
        Uri.parse(url),
        body: '2,$fileName',
      );
      if (response.statusCode == 200) {
        _showDialog("Success", "Sunrise & Sunset sound changed to $fileName");
        await _saveSettings();
      } else {
        _showDialog("Error", "Failed with status: ${response.statusCode}");
      }
    } catch (e) {
      _showDialog("Connection Error", "Make sure you're connected to the speaker's Wi-Fi.\n\nError: $e");
    }

    setState(() => _isSunriseLoading = false);
  }

  // Upload audio file to IoT device using the new API endpoints
  Future<void> _uploadAudioFile(File file, String fileName, bool isNamaz) async {
    setState(() => _isUploadingFile = true);

    try {
      // Create multipart request
      var request = http.MultipartRequest(
          'POST',
          Uri.parse('http://192.168.2.1/upload/${isNamaz ? 'namaz' : 'pooja'}/$fileName')
      );

      // Add file to request
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: fileName,
      ));

      // Send request
      var response = await request.send();

      if (response.statusCode == 200) {
        _showDialog("Success", "File uploaded successfully: $fileName");

        // Update the selected sound and refresh the sound list
        if (isNamaz) {
          setState(() => _selectedNamazSound = fileName);
          await _fetchNamazSounds();
          await _sendNamazSoundRequest();
        } else {
          setState(() => _selectedSunriseSound = fileName);
          await _fetchSunriseSounds();
          await _sendSunriseSoundRequest();
        }
      } else {
        _showDialog("Error", "Failed to upload file: ${response.statusCode}");
      }
    } catch (e) {
      _showDialog("Connection Error", "Make sure you're connected to the speaker's Wi-Fi.\n\nError: $e");
    }

    setState(() => _isUploadingFile = false);
  }

  // Pick audio file from device storage and upload to IoT device
  Future<void> _pickAudioFile(bool isNamaz) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      String fileName = result.files.single.name;

      // Check if the file has an audio extension
      if (fileName.toLowerCase().endsWith('.mp3') ||
          fileName.toLowerCase().endsWith('.wav') ||
          fileName.toLowerCase().endsWith('.ogg') ||
          fileName.toLowerCase().endsWith('.m4a')) {

        // Upload the file using the new API
        await _uploadAudioFile(File(filePath), fileName, isNamaz);
      } else {
        _showDialog("Invalid File", "Please select an audio file (MP3, WAV, OGG, M4A)");
      }
    }
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
            child: const Text("OK"),
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
      body: _isFetchingSounds || _isUploadingFile
          ? Center(child: CircularProgressIndicator(color: themeProvider.selectedColor))
          : Container(
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              color: Colors.grey[50],
              child: Column(
                children: [
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
                    title: const Text('Namaz'),
                    trailing: Switch(
                      value: _namazEnabled,
                      onChanged: (value) async {
                        setState(() {
                          _namazEnabled = value;
                        });
                        await _sendNamazRequest(value);
                        await _saveSettings();
                      },
                      activeColor: themeProvider.selectedColor,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sound',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                        ),
                        _namazSoundFiles.isEmpty
                            ? const Text(
                          'No sounds available',
                          style: TextStyle(color: Colors.grey),
                        )
                            : DropdownButton<String>(
                          value: _selectedNamazSound.isNotEmpty && _namazSoundFiles.contains(_selectedNamazSound)
                              ? _selectedNamazSound
                              : _namazSoundFiles.isNotEmpty
                              ? _namazSoundFiles[0]
                              : '',
                          items: _namazSoundFiles.map((file) {
                            return DropdownMenuItem<String>(
                              value: file,
                              child: Text(
                                file,
                                style: const TextStyle(fontWeight: FontWeight.w400),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            if (value != null) {
                              setState(() => _selectedNamazSound = value);
                              await _sendNamazSoundRequest();
                            }
                          },
                          underline: const SizedBox(),
                          icon: const Icon(Icons.chevron_right, color: Colors.grey),
                          isDense: true,
                          alignment: Alignment.centerRight,
                          style: const TextStyle(fontWeight: FontWeight.w400, color: Colors.black),
                          selectedItemBuilder: (BuildContext context) {
                            return _namazSoundFiles.map((file) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  file,
                                  style: const TextStyle(fontWeight: FontWeight.w400),
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ],
                    ),
                  ),
                  // Time Adjustment Slider for Namaz - UPDATED
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Time Adjustment',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '0m',
                              style: TextStyle(
                                color: _namazOffset == 0
                                    ? themeProvider.selectedColor
                                    : Colors.grey,
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _namazOffset,
                                min: 0,
                                max: 30,
                                divisions: 30,
                                label: '${_namazOffset.round()}m',
                                onChanged: (value) {
                                  setState(() {
                                    _namazOffset = value;
                                  });
                                },
                                activeColor: themeProvider.selectedColor,
                                inactiveColor: Colors.grey[300],
                              ),
                            ),
                            Text(
                              '30m',
                              style: TextStyle(
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
                            style: TextStyle(
                              color: themeProvider.selectedColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Center(

                      ///Expanded(
                      //   child: _isNamazLoading
                      //       ? Center(child: CircularProgressIndicator(color: themeProvider.selectedColor))
                      //       : ElevatedButton.icon(
                      //         onPressed: _namazSoundFiles.isEmpty ? null : _sendNamazSoundRequest,
                      //         icon: Icon(Icons.music_note, color: themeProvider.selectedColor),
                      //         label: Text(
                      //           'Upload Sound',
                      //           style: TextStyle(color: themeProvider.selectedColor, fontSize: 14),
                      //         ),
                      //         style: ElevatedButton.styleFrom(
                      //           backgroundColor: Colors.grey[100],
                      //           foregroundColor: Colors.black,
                      //           elevation: 0,
                      //           shape: RoundedRectangleBorder(
                      //             borderRadius: BorderRadius.circular(10),
                      //           ),
                      //         ),
                      //       ),
                      // ),
                      // const SizedBox(width: 10),
                      child: ElevatedButton.icon(
                        onPressed: () => _pickAudioFile(true),
                        icon: Icon(Icons.upload_file, color: themeProvider.selectedColor),
                        label: Text(
                          'New',
                          style: TextStyle(color: themeProvider.selectedColor, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.grey[50],
              child: Column(
                children: [
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
                    title: const Text('Sunrise & Sunset'),
                    trailing: Switch(
                      value: _sunriseEnabled,
                      onChanged: (value) async {
                        setState(() {
                          _sunriseEnabled = value;
                        });
                        await _sendSunriseSunsetRequest(value);
                        await _saveSettings();
                      },
                      activeColor: themeProvider.selectedColor,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sound',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                        ),
                        _sunriseSoundFiles.isEmpty
                            ? const Text(
                          'No sounds available',
                          style: TextStyle(color: Colors.grey),
                        )
                            : DropdownButton<String>(
                          value: _selectedSunriseSound.isNotEmpty && _sunriseSoundFiles.contains(_selectedSunriseSound)
                              ? _selectedSunriseSound
                              : _sunriseSoundFiles.isNotEmpty
                              ? _sunriseSoundFiles[0]
                              : '',
                          items: _sunriseSoundFiles.map((file) {
                            return DropdownMenuItem<String>(
                              value: file,
                              child: Text(
                                file,
                                style: const TextStyle(fontWeight: FontWeight.w400),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            if (value != null) {
                              setState(() => _selectedSunriseSound = value);
                              await _sendSunriseSoundRequest();
                            }
                          },
                          underline: const SizedBox(),
                          icon: const Icon(Icons.chevron_right, color: Colors.grey),
                          isDense: true,
                          alignment: Alignment.centerRight,
                          style: const TextStyle(fontWeight: FontWeight.w400, color: Colors.black),
                          selectedItemBuilder: (BuildContext context) {
                            return _sunriseSoundFiles.map((file) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  file,
                                  style: const TextStyle(fontWeight: FontWeight.w400),
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ],
                    ),
                  ),
                  // Time Adjustment Slider for Sunrise/Sunset - UPDATED
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Time Adjustment',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '0m',
                              style: TextStyle(
                                color: _sunriseOffset == 0
                                    ? themeProvider.selectedColor
                                    : Colors.grey,
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _sunriseOffset,
                                min: 0,
                                max: 30,
                                divisions: 30,
                                label: '${_sunriseOffset.round()}m',
                                onChanged: (value) {
                                  setState(() {
                                    _sunriseOffset = value;
                                  });
                                },
                                activeColor: themeProvider.selectedColor,
                                inactiveColor: Colors.grey[300],
                              ),
                            ),
                            Text(
                              '30m',
                              style: TextStyle(
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
                            style: TextStyle(
                              color: themeProvider.selectedColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Center(

                      // Expanded(
                      //   child: _isSunriseLoading
                      //       ? Center(child: CircularProgressIndicator(color: themeProvider.selectedColor))
                      //       : ElevatedButton.icon(
                      //         onPressed: _sunriseSoundFiles.isEmpty ? null : _sendSunriseSoundRequest,
                      //         icon: Icon(Icons.music_note, color: themeProvider.selectedColor),
                      //         label: Text(
                      //           'Upload Sound',
                      //           style: TextStyle(color: themeProvider.selectedColor, fontSize: 14),
                      //         ),
                      //         style: ElevatedButton.styleFrom(
                      //           backgroundColor: Colors.grey[100],
                      //           foregroundColor: Colors.black,
                      //           elevation: 0,
                      //           shape: RoundedRectangleBorder(
                      //             borderRadius: BorderRadius.circular(10),
                      //           ),
                      //         ),
                      //       ),
                      // ),
                      // const SizedBox(width: 10),
                      child: ElevatedButton.icon(
                        onPressed: () => _pickAudioFile(false),
                        icon: Icon(Icons.upload_file, color: themeProvider.selectedColor),
                        label: Text(
                          'New',
                          style: TextStyle(color: themeProvider.selectedColor, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}