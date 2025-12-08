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

  // Local recordings: Now stores path, name, and duration
  List<Map<String, String>> localSongs = []; // <<== UPDATED

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
    // _fetchApiSongs(); // fetch API songs (controls apiStatus & _apiLoaded)
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

  /// ----------------- HELPER FUNCTIONS -----------------
  String _formatDuration(Duration? duration) {
    if (duration == null) return '??:??'; // Changed default to show unknown
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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

      // <<== NEW LOGIC: Calculate duration for each local file ==>>
      List<Map<String, String>> calculatedRecordings = [];
      final tempPlayer = AudioPlayer(); // Temporary player for duration check

      for (var file in mp3Files) {
        String durationString = '??:??';
        try {
          await tempPlayer.setFilePath(file.path);
          durationString = _formatDuration(tempPlayer.duration);
        } catch (e) {
          debugPrint('Error getting duration for ${file.path}: $e');
        }

        calculatedRecordings.add({
          'path': file.path,
          'name': file.path.split('/').last,
          'duration': durationString,
        });
      }
      await tempPlayer.dispose(); // IMPORTANT: Dispose the temporary player
      // <<======================================================>>


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
        localSongs = calculatedRecordings; // <<== UPDATED
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
      final filePath = localSongs[index]['path']!; // <<== UPDATED
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
        localSongs.removeAt(index); // <<== UPDATED
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
  // (API methods remain unchanged as duration is not available from API)

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

  /// ----------------- WIFI & PERMISSIONS -----------------
  // (Methods remain unchanged)
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

  Future<bool> _requestPermissions() async {
    try {
      List<Permission> permissionsToRequest = [];

      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdk = androidInfo.version.sdkInt;

        permissionsToRequest.addAll([
          Permission.microphone,
          Permission.manageExternalStorage,
          Permission.storage,
          Permission.mediaLibrary,
          Permission.locationWhenInUse,
          Permission.locationAlways,
        ]);

        if (sdk >= 33) {
          permissionsToRequest.addAll([
            Permission.audio,
            Permission.accessMediaLocation,
            Permission.nearbyWifiDevices,
          ]);
        }
      } else {
        permissionsToRequest.addAll([
          Permission.microphone,
          Permission.mediaLibrary,
          Permission.locationWhenInUse,
        ]);
      }

      await permissionsToRequest.request();
      return true;
    } catch (e) {
      debugPrint("Permission error: $e");
      return false;
    }
  }

  Future<void> _pickAndUploadMusic() async {
    try {
      // 1. Use file_picker package for more reliable file picking
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

        // --- DURATION CHECK START ---
        const int maxDurationSeconds = 120; // Maximum duration: 2 minutes

        // Use a new temporary AudioPlayer instance to get the duration
        final tempPlayer = AudioPlayer();
        Duration? duration;

        try {
          await tempPlayer.setFilePath(filePath);
          duration = tempPlayer.duration;
        } catch (e) {
          debugPrint('Error getting audio duration: $e');
          if (mounted) {
            AppAlert.warning(
              context,
              text: 'Could not determine file duration. Uploading anyway...',
            );
          }
        } finally {
          await tempPlayer.dispose();
        }

        if (duration != null && duration.inSeconds > maxDurationSeconds) {
          if (mounted) {
            final maxMinutes = maxDurationSeconds ~/ 60;
            final fileMinutes = duration.inMinutes;
            final fileSeconds = duration.inSeconds % 60;
            AppAlert.error(
              context,
              text: 'File is too long! Max allowed is $maxMinutes minutes. '
                  'This file is ${fileMinutes}m ${fileSeconds}s.',
            );
          }
          return; // Stop the upload process
        }
        // --- DURATION CHECK END ---

        // Upload the file
        final newFile = await BellService().uploadMp3(
          context,
          filePath,
          isWifiConnected,
        );

        if (newFile != null && mounted) {
          // Wait for 3 seconds (matching the BellService SnackBar duration)
          await Future.delayed(const Duration(seconds: 3));

          // Now refresh the library
          await _loadUploadedFiles(); // Refreshes local list and server list via BellService.fetchSoundFiles
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
                        ? _buildLibraryList() // IoT Device Songs
                        : _buildMyMusicList(), // Local Recordings
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
        // 1. Close the menu
        setState(() => _isFabMenuOpen = false);
        await Future.delayed(const Duration(milliseconds: 300));

        // 2. Check which option was clicked
        if (title == 'Record Music') {
          // Call the recording logic (which handles its own permissions internally)
          await _handleRecordMusic();
        } else {
          // Default to Add Music logic
          await _requestPermissions(); // Request permissions first
          await _pickAndUploadMusic(); // Open file picker
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

  // ----------------- IoT Device Song List (Beautified) -----------------
  Widget _buildLibraryList() {
    // Option C:
    if (!_apiLoaded) {
      return const SizedBox(); // blank until API response arrives
    }

    if (apiSongs.isEmpty) {
      return Center(
        child: Text(
          apiStatus ?? 'No songs available on device.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: apiSongs.length,
        itemBuilder: (context, index) {
          final song = apiSongs[index];
          final isPlaying = currentlyPlayingApiSong == song;

          // Duration Placeholder: Since API doesn't provide duration, we show a placeholder.
          const String durationText = '??:?? (Device)';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note_outlined, color: Colors.orange, size: 24),
                ),
                title: Text(
                  song,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                // subtitle: Text(
                //   'Duration: $durationText', // Display Duration Placeholder
                //   style: AppTextStyles.small.copyWith(color: Colors.grey[600]),
                // ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: isPlaying ? Colors.blueAccent : Colors.orange,
                        size: 32, // Increased size
                      ),
                      onPressed: () =>
                      isPlaying ? _pauseApiSong() : _playApiSong(song),
                    ),
                    IconButton(
                      icon:
                      const Icon(Icons.delete_outline, color: Colors.red, size: 24), // Beautified icon
                      onPressed: () => _deleteApiSong(song),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  // ----------------- Local Music List (Beautified) -----------------
  Widget _buildMyMusicList() {
    if (localSongs.isEmpty) { // <<== UPDATED to localSongs
      return Center(
        child: Text('No recordings yet.\nTap the microphone button to record something!',
            textAlign: TextAlign.center, style: AppTextStyles.body),
      );
    }

    final themeProvider = Provider.of<ThemeProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: localSongs.length, // <<== UPDATED to localSongs
        itemBuilder: (context, index) {
          final songData = localSongs[index];
          final filePath = songData['path']!;
          final fileName = songData['name']!;
          final duration = songData['duration']!; // <<== USING STORED DURATION

          final isPlaying = _currentlyPlayingIndex == index && _player?.playing == true;

          return Dismissible(
            key: Key(filePath),
            direction: DismissDirection.endToStart, // Only swipe left
            background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white)),
            onDismissed: (_) => _deleteRecording(index, filePath),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10), // Margin moved to Padding
              child: Container(
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Added padding
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8), // Smaller border radius
                    child: Container(
                      width: 50,
                      height: 50,
                      color: themeProvider.selectedColor.withOpacity(0.15),
                      child: Icon(Icons.mic, color: themeProvider.selectedColor, size: 28), // Changed image to Mic icon
                    ),
                  ),
                  title: Text(
                    fileName,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // subtitle: Text(
                  //   'Duration: $duration', // Display actual duration
                  //   style: AppTextStyles.small.copyWith(color: Colors.grey[600]),
                  // ),
                  trailing: Icon(
                      isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      color: themeProvider.selectedColor,
                      size: 32), // Increased size
                  onTap: () => _playRecording(index),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}