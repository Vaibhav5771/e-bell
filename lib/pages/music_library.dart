import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:quickalert/quickalert.dart';

import 'comingsoon.dart';
import '../music_tabs/recordingpage.dart';
import '../services/services.dart';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';
import 'tablogic1.dart';
import '../utils/quickalert.dart'; // Make sure to import QuickAlert

class MusicLibrary extends StatefulWidget {
  final TabLogic1 tabLogic;
  const MusicLibrary({super.key, required this.tabLogic});

  @override
  _MusicLibraryState createState() => _MusicLibraryState();
}

class _MusicLibraryState extends State<MusicLibrary> {
  bool _isFabMenuOpen = false;
  bool isWifiConnected = false;
  String connectionStatus = "Checking Wi-Fi...";
  Timer? wifiCheckTimer;
  final String targetSsid = "IoGen_Speaker";

  // Local recordings
  List<String> recordings = [];

  // API songs
  List<String> apiSongs = [];
  String? currentlyPlayingApiSong;

  // API status & loaded flag (for Option C)
  String? apiStatus; // success message or error string
  bool _apiLoaded = false;

  // Audio player
  AudioPlayer? _player;
  int? _currentlyPlayingIndex;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _startWifiMonitoring();
    _player = AudioPlayer();
    _initPlayer();
    _loadUploadedFiles(); // load local recordings (no loader)
    _fetchApiSongs(); // fetch API songs (controls apiStatus & _apiLoaded)
  }

  @override
  void dispose() {
    wifiCheckTimer?.cancel();
    _playerStateSubscription?.cancel();
    _player?.stop();
    _player?.dispose();
    _player = null;
    super.dispose();
  }

  /// ----------------- AUDIO PLAYER -----------------
  Future<void> _initPlayer() async {
    _playerStateSubscription = _player?.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          if (state.processingState == ProcessingState.completed) {
            _currentlyPlayingIndex = null;
            currentlyPlayingApiSong = null;
          }
        });
      }
    });
  }

  /// ----------------- RECORDINGS -----------------
  Future<void> _loadUploadedFiles() async {
    try {
      // 1️⃣ Load local recordings from app directory
      final dir = await getApplicationDocumentsDirectory();
      final recDir = Directory('${dir.path}/recordings');
      if (!await recDir.exists()) await recDir.create(recursive: true);

      final files = await recDir.list().toList();
      final mp3Files = files
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.mp3'))
          .toList();

      // Sort by modified date (latest first)
      mp3Files.sort(
              (a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      final localRecordings = mp3Files.map((f) => f.path).toList();

      // 2️⃣ Also try to fetch uploaded files from IoT device (BellService).
      // Note: We still call fetchSoundFiles here to keep the behavior consistent.
      List<String> uploadedFiles = [];
      try {
        final bellService = BellService();
        final result = await bellService.fetchSoundFiles(context);
        if (result != null) uploadedFiles = result;
      } catch (e) {
        // Don't block UI for this; just log. The main API call _fetchApiSongs will set apiStatus.
        debugPrint('BellService.fetchSoundFiles error: $e');
      }

      if (!mounted) return;
      setState(() {
        recordings = localRecordings;
        // If BellService returned files, prefer that for API list, else keep existing apiSongs
        if (uploadedFiles.isNotEmpty) {
          apiSongs = uploadedFiles;
          apiStatus = 'Loaded ${uploadedFiles.length} songs from device.';
          _apiLoaded = true;
        }
      });
    } catch (e) {
      if (mounted) {
        AppAlert.error(
          context,
          text: 'Error loading local files: $e',
        );
      }
    }
  }

  Future<void> _playRecording(int index) async {
    try {
      final filePath = recordings[index];
      final file = File(filePath);

      if (!await file.exists()) return;

      if (_currentlyPlayingIndex == index && _player?.playing == true) {
        await _player?.pause();
        return;
      }

      if (_currentlyPlayingIndex == index && _player?.playing == false) {
        await _player?.play();
        return;
      }

      await _player?.stop();
      setState(() => _currentlyPlayingIndex = index);
      await _player?.setFilePath(filePath);
      await _player?.play();
    } catch (e) {
      if (mounted) {
        AppAlert.error(
          context,
          text: 'Error playing audio: $e',
        );
      }
      setState(() => _currentlyPlayingIndex = null);
    }
  }

  Future<void> _deleteRecording(int index, String filePath) async {
    try {
      final file = File(filePath);
      await file.delete();
      setState(() {
        recordings.removeAt(index);
        if (_currentlyPlayingIndex != null &&
            _currentlyPlayingIndex! >= index) {
          if (_currentlyPlayingIndex == index) {
            _currentlyPlayingIndex = null;
            _player?.stop();
          } else {
            _currentlyPlayingIndex = _currentlyPlayingIndex! - 1;
          }
        }
      });
      if (mounted) {
        AppAlert.success(
          context,
          text: 'Recording deleted successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(
          context,
          text: 'Error deleting file: $e',
        );
      }
    }
  }

  /// ----------------- API SONGS -----------------
  Future<void> _fetchApiSongs() async {
    // Option C behavior:
    // - show nothing until the API call completes
    // - after completion, _apiLoaded = true and apiStatus is set to success or error
    try {
      final response =
      await http.get(Uri.parse("http://192.168.2.1/alarmsong/"));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List<dynamic> files = jsonResponse["Data"][0]["files"];
        final fetched = files.map((e) => e[0].toString()).toList();
        if (!mounted) return;
        setState(() {
          apiSongs = fetched;
          _apiLoaded = true;
          if (fetched.isEmpty) {
            apiStatus = 'No songs on device.';
          } else {
            apiStatus = 'Loaded ${fetched.length} songs.';
          }
        });
     } //else {
      //   if (!mounted) return;
      //   setState(() {
      //     apiSongs = [];
      //     _apiLoaded = true;
      //     apiStatus = 'Error fetching songs. Status: ${response.statusCode}';
      //   });
      //   debugPrint('Error fetching API songs. Status: ${response.statusCode}');
      // }
    } catch (e) {
      // if (!mounted) return;
      // setState(() {
      //   apiSongs = [];
      //   _apiLoaded = true;
      //   apiStatus = 'Error fetching songs: $e';
      // });
      // debugPrint('Error fetching API songs: $e');
    }
  }

  Future<void> _playApiSong(String songName) async {
    try {
      // First, send stop API call
      final stopResponse = await http.post(
        Uri.parse("http://192.168.2.1/preview/"),
        body: "0",
      );

      if (stopResponse.statusCode != 200) {
        debugPrint(
            'Warning: Stop API call failed with status: ${stopResponse.statusCode}');
      }

      // Add a small delay to ensure the stop command is processed
      await Future.delayed(const Duration(milliseconds: 200));

      // Then send the preview API call
      final response = await http.post(
        Uri.parse("http://192.168.2.1/preview/"),
        body: "1,$songName",
      );

      if (response.statusCode == 200) {
        setState(() {
          currentlyPlayingApiSong = songName;
          _currentlyPlayingIndex = null;
          _player?.stop();
        });
      } else {
        debugPrint(
            'Error: Preview API call failed with status: ${response.statusCode}');
        if (mounted) {
          AppAlert.error(
            context,
            text: 'Failed to play song. Status: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      debugPrint('Error playing API song: $e');
      if (mounted) {
        AppAlert.error(
          context,
          text: 'Error playing API song: $e',
        );
      }
    }
  }

  Future<void> _pauseApiSong() async {
    try {
      final response = await http.post(
        Uri.parse("http://192.168.2.1/preview/"),
        body: "0",
      );
      if (response.statusCode == 200) {
        setState(() {
          currentlyPlayingApiSong = null;
        });
      }
    } catch (e) {
      debugPrint('Error pausing API song: $e');
    }
  }

  Future<void> _deleteApiSong(String fileName) async {
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirm Delete'),
            content: Text(
                "Are you sure you want to delete '$fileName'? This action cannot be undone."),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  Navigator.of(context).pop(); // Close the dialog
                  try {
                    // Construct POST body in the new API format
                    // filename,hour,min,s_epoch,e_epoch,weeks
                    final body = "$fileName,0,0,0,0,0";

                    final response = await http.post(
                      Uri.parse("http://192.168.2.1/delete/"),
                      body: body,
                    );

                    if (response.statusCode == 200) {
                      setState(() {
                        apiSongs.remove(fileName);
                      });
                      if (mounted) {
                        AppAlert.success(
                          context,
                          text: "Successfully deleted: $fileName",
                        );
                      }
                    } else {
                      debugPrint(
                          'Failed to delete API song. Status: ${response.statusCode}');
                      if (mounted) {
                        AppAlert.error(
                          context,
                          text:
                          'Failed to delete song. Status: ${response.statusCode}',
                        );
                      }
                    }
                  } catch (e) {
                    debugPrint('Error deleting API song: $e');
                    if (mounted) {
                      AppAlert.error(
                        context,
                        text: 'Error deleting API song: $e',
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      );
    }
  }

  /// ----------------- WIFI -----------------
  Future<void> _startWifiMonitoring() async {
    await _checkWifiConnection();
    wifiCheckTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _checkWifiConnection());
  }

  Future<void> _checkWifiConnection() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        String? wifiSSID = await NetworkInfo().getWifiName();
        setState(() {
          isWifiConnected = true;
          connectionStatus = wifiSSID != null &&
              wifiSSID.toLowerCase() == targetSsid.toLowerCase()
              ? "Connected to $targetSsid"
              : "Connected to Wi-Fi: ${wifiSSID ?? 'Unknown'}";
        });
      } else {
        setState(() {
          isWifiConnected = false;
          connectionStatus = "Not connected to Wi-Fi";
        });
      }
    } catch (e) {
      setState(() {
        isWifiConnected = false;
        connectionStatus = "Error checking Wi-Fi: $e";
      });
    }
  }

  /// ----------------- PERMISSIONS -----------------
  Future<bool> _requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses;
      List<Permission> permissionsToRequest = [];

      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdk = androidInfo.version.sdkInt;

        // Base permissions
        permissionsToRequest.addAll([
          Permission.microphone,
          Permission.manageExternalStorage, // For broader file access
        ]);

        // Location permissions for WiFi
        permissionsToRequest.addAll([
          Permission.locationWhenInUse,
          Permission.locationAlways,
        ]);

        // Storage permissions based on SDK
        if (sdk >= 33) { // Android 13+
          permissionsToRequest.addAll([
            Permission.audio,
            Permission.accessMediaLocation,
            Permission.nearbyWifiDevices,
          ]);
        } else {
          permissionsToRequest.addAll([
            Permission.storage,
            Permission.accessMediaLocation,
          ]);
        }

        // Additional permissions for file access
        permissionsToRequest.addAll([
          Permission.mediaLibrary,
        ]);
      } else {
        // iOS permissions
        permissionsToRequest.addAll([
          Permission.locationWhenInUse,
          Permission.locationAlways,
          Permission.microphone,
          Permission.mediaLibrary,
        ]);
      }

      // Request permissions
      statuses = await permissionsToRequest.request();

      // Log permission status for debugging
      if (kDebugMode) {
        statuses.forEach((permission, status) {
          debugPrint('Permission $permission: $status');
        });
      }

      // Check if essential permissions are granted
      bool essentialGranted = true;

      // Essential permissions that must be granted
      final essentialPermissions = [
        Permission.microphone,
        if (Platform.isAndroid) Permission.manageExternalStorage,
      ];

      for (var permission in essentialPermissions) {
        final status = statuses[permission];
        if (status != null && !status.isGranted) {
          essentialGranted = false;
          debugPrint('Essential permission $permission denied');
        }
      }

      // For location permissions, handle partial grants
      final locationStatus = statuses[Permission.locationWhenInUse] ??
          statuses[Permission.locationAlways];
      if (locationStatus != null && !locationStatus.isGranted) {
        debugPrint('Location permission denied - WiFi features may not work');
      }

      return essentialGranted;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  Future<void> _handleAddMusic() async {
    try {
      // First, check if we have necessary permissions
      final storageStatus = await Permission.manageExternalStorage.status;
      final mediaStatus = await Permission.mediaLibrary.status;

      if (!storageStatus.isGranted || !mediaStatus.isGranted) {
        // Show a custom dialog that matches your app's UI
        if (mounted) {
          await _showStoragePermissionDialog();
        }
      } else {
        await _pickAndUploadMusic();
      }
    } catch (e) {
      debugPrint('Error in _handleAddMusic: $e');
      if (mounted) {
        AppAlert.error(
          context,
          text: 'Failed to add music: $e',
        );
      }
    }
  }

  Future<void> _showStoragePermissionDialog() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // Using QuickAlert to match your app's style
    await QuickAlert.show(
      context: context,
      type: QuickAlertType.warning,
      title: 'Storage Permission Required',
      text: 'To add music files, the app needs access to your device storage. Please grant the permission when prompted.',
      confirmBtnText: 'Continue',
      cancelBtnText: 'Cancel',
      showCancelBtn: true,
      confirmBtnColor: themeProvider.selectedColor,
      onConfirmBtnTap: () async {
        Navigator.pop(context); // Close the dialog
        await _requestPermissions();
        await _pickAndUploadMusic();
      },
      onCancelBtnTap: () {
        Navigator.pop(context); // Close the dialog
      },
    );
  }

  Future<void> _pickAndUploadMusic() async {
    try {
      // Use file_picker package for more reliable file picking
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;

        // Verify file exists and is accessible
        final file = File(filePath);
        final exists = await file.exists();

        if (!exists) {
          throw Exception('Selected file is not accessible');
        }

        // Upload the file
        final newFile = await BellService().uploadMp3(
          context,
          filePath,
          isWifiConnected,
        );

        if (newFile != null && mounted) {
          // --- CHANGE STARTS HERE ---
          
          // Wait for 3 seconds (matching the BellService SnackBar duration)
          // This gives the server time to process the file and allows the user to read the success message.
          await Future.delayed(const Duration(seconds: 3));

          // Now refresh the library
          await _loadUploadedFiles(); // Refreshes local list
          await _fetchApiSongs();     // Refreshes server list
          
          AppAlert.success(
            context,
            text: 'Music library updated!',
          );
          // --- CHANGE ENDS HERE ---
        }
      }
    } on PlatformException catch (e) {
      debugPrint('File picker platform exception: $e');
      if (mounted) {
        AppAlert.error(
          context,
          text: 'File access denied. Please check app permissions in settings.',
        );
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        AppAlert.error(
          context,
          text: 'Error selecting file: $e',
        );
      }
    }
  }

  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid)
      return (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    return 0;
  }

  /// ----------------- UI -----------------
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          GestureDetector(
            onTap: () {
              if (_isFabMenuOpen) {
                setState(() {
                  _isFabMenuOpen = false;
                });
              }
            },
            child: Column(
              children: [
                // Tabs & Wifi
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Text(connectionStatus,
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 80),
                    child: widget.tabLogic.selectedTabIndex == 0
                        ? _buildLibraryList()
                        : _buildMyMusicList(),
                  ),
                ),
              ],
            ),
          ),
          if (_isFabMenuOpen)
            Positioned(
              bottom: 80,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  // This prevents the menu from closing when clicking inside it
                },
                child: Container(
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildFabOption('Add Music'),
                      _buildFabOption('Record Music'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isFabMenuOpen = !_isFabMenuOpen;
          });
        },
        backgroundColor: themeProvider.selectedColor,
        shape: const CircleBorder(), // Changed back to circle for consistency
        child: Icon(
          _isFabMenuOpen ? Icons.close : Icons.music_note,
          color: Colors.white, // Changed to white for better contrast
          size: 28,
        ),
      ),
    );
  }

  Widget _buildFabOption(String title) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return ListTile(
      leading: Icon(title == 'Add Music' ? Icons.add : Icons.mic,
          color: themeProvider.selectedColor),
      title: Text(title, style: AppTextStyles.body),
      onTap: () async {
        setState(() => _isFabMenuOpen = false);
        await Future.delayed(const Duration(milliseconds: 300));

        if (title == 'Add Music') {
          await _handleAddMusic(); // Use the new method
        } else {
          await _handleRecordMusic();
        }
      },
    );
  }

  Future<void> _handleRecordMusic() async {
    try {
      var micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        micStatus = await Permission.microphone.request();
      }

      if (micStatus.isGranted) {
        final newRecordingPath = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (context) => const AudioRecorderPage()),
        );

        if (newRecordingPath != null && mounted) {
          await _loadUploadedFiles();
          AppAlert.success(
            context,
            text: 'Recording saved successfully!',
          );
        }
      } else {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Microphone Permission Required'),
              content: const Text(
                'Recording audio requires microphone access. '
                    'Please enable it in app settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in _handleRecordMusic: $e');
      if (mounted) {
        AppAlert.error(
          context,
          text: 'Failed to start recording: $e',
        );
      }
    }
  }

  Widget _buildLibraryList() {
    // Option C:
    // - If API not loaded yet -> return blank (SizedBox) so UI stays as-is
    // - If API loaded and list is empty -> show apiStatus (No songs or error)
    // - If API loaded and list has items -> show the list
    if (!_apiLoaded) {
      return const SizedBox(); // blank until API response arrives
    }

    if (apiSongs.isEmpty) {
      return Center(
        child: Text(
          apiStatus ?? 'No songs available.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: apiSongs.length,
            itemBuilder: (context, index) {
              final song = apiSongs[index];
              final isPlaying = currentlyPlayingApiSong == song;
              return ListTile(
                leading: Icon(Icons.music_note, color: Colors.grey[600]),
                title: Text(
                  song,
                  style: AppTextStyles.body.copyWith(color: Colors.black87),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: Colors.orange,
                          size: 28),
                      onPressed: () =>
                      isPlaying ? _pauseApiSong() : _playApiSong(song),
                    ),
                    IconButton(
                      icon:
                      const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => _deleteApiSong(song),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMyMusicList() {
    // No loader; if local recordings list is empty, show placeholder text
    if (recordings.isEmpty) {
      return Center(
        child: Text('No recordings yet.\nTap the + button to record something!',
            textAlign: TextAlign.center, style: AppTextStyles.body),
      );
    }

    final themeProvider = Provider.of<ThemeProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recordings.length,
        itemBuilder: (context, index) {
          final filePath = recordings[index];
          final fileName = filePath.split('/').last;
          return Dismissible(
            key: Key(filePath),
            background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white)),
            onDismissed: (_) => _deleteRecording(index, filePath),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/Music.jpg',
                      width: 50, height: 50, fit: BoxFit.cover),
                ),
                title: Text(fileName, style: AppTextStyles.body),
                subtitle: Text('00:00', style: AppTextStyles.small),
                trailing: Icon(
                    _currentlyPlayingIndex == index && _player?.playing == true
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: themeProvider.selectedColor,
                    size: 30),
                onTap: () => _playRecording(index),
              ),
            ),
          );
        },
      ),
    );
  }
}