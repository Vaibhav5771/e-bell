import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import 'comingsoon.dart';
import '../music_tabs/recordingpage.dart';
import '../services/services.dart';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';
import 'tablogic1.dart';

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
  bool _isLoading = true;

  // API songs
  List<String> apiSongs = [];
  String? currentlyPlayingApiSong;

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
    _loadUploadedFiles();
    _fetchApiSongs();
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
    setState(() => _isLoading = true);

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
      mp3Files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      final localRecordings = mp3Files.map((f) => f.path).toList();

      // 2️⃣ Fetch uploaded files from IoT device using BellService
      final bellService = BellService();
      final uploadedFiles = await bellService.fetchSoundFiles(context);

      // 3️⃣ Merge lists & remove duplicates
      final allSongs = <String>{
        ...uploadedFiles,
        ...localRecordings.map((f) => f.split(Platform.pathSeparator).last),
      }.toList();

      // 4️⃣ Update UI
      if (!mounted) return;
      setState(() {
        recordings = localRecordings; // local device recordings
        apiSongs = uploadedFiles; // songs fetched from IoT
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading uploaded files: $e', style: AppTextStyles.body),
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e', style: AppTextStyles.body)),
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
        if (_currentlyPlayingIndex != null && _currentlyPlayingIndex! >= index) {
          if (_currentlyPlayingIndex == index) {
            _currentlyPlayingIndex = null;
            _player?.stop();
          } else {
            _currentlyPlayingIndex = _currentlyPlayingIndex! - 1;
          }
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording deleted', style: AppTextStyles.body)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting file: $e', style: AppTextStyles.body)),
        );
      }
    }
  }

  /// ----------------- API SONGS -----------------
  Future<void> _fetchApiSongs() async {
    try {
      final response = await http.get(Uri.parse("http://192.168.2.1/alarmsong/"));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List<dynamic> files = jsonResponse["Data"][0]["files"];
        setState(() {
          apiSongs = files.map((e) => e[0].toString()).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching API songs: $e');
    }
  }

  Future<void> _playApiSong(String songName) async {
    try {
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
      }
    } catch (e) {
      debugPrint('Error playing API song: $e');
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Deleted: $fileName", style: AppTextStyles.body),
            ),
          );
        }
      } else {
        debugPrint('Failed to delete API song. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting API song: $e');
    }
  }


  /// ----------------- WIFI -----------------
  Future<void> _startWifiMonitoring() async {
    await _checkWifiConnection();
    wifiCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkWifiConnection());
  }

  Future<void> _checkWifiConnection() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        String? wifiSSID = await NetworkInfo().getWifiName();
        setState(() {
          isWifiConnected = true;
          connectionStatus = wifiSSID != null && wifiSSID.toLowerCase() == targetSsid.toLowerCase()
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
    Map<Permission, PermissionStatus> statuses;

    if (Platform.isAndroid) {
      final sdk = await _getAndroidVersion();
      if (sdk >= 33) {
        statuses = await [
          Permission.location,
          Permission.audio,
          Permission.microphone,
          Permission.nearbyWifiDevices
        ].request();
      } else {
        statuses = await [
          Permission.location,
          Permission.storage,
          Permission.microphone,
          Permission.nearbyWifiDevices
        ].request();
      }
    } else {
      statuses = await [
        Permission.location,
        Permission.microphone,
        Permission.nearbyWifiDevices
      ].request();
    }

    // Check if all required permissions are granted
    bool allGranted = statuses.values.every((status) => status.isGranted);
    return allGranted;
  }


  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) return (await DeviceInfoPlugin().androidInfo).version.sdkInt;
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
          Column(
            children: [
              // Tabs & Wifi
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 35,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: widget.tabLogic.buildTab(
                              context: context,
                              text: 'Library',
                              index: 0,
                              onTap: () => setState(() => widget.tabLogic.setSelectedTab(0)),
                            ),
                          ),
                          Expanded(
                            child: widget.tabLogic.buildTab(
                              context: context,
                              text: 'My Music',
                              index: 1,
                              onTap: () => setState(() => widget.tabLogic.setSelectedTab(1)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(connectionStatus, style: AppTextStyles.body, textAlign: TextAlign.center),
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
          if (_isFabMenuOpen)
            Positioned(
              bottom: 80,
              right: 16,
              child: Container(
                width: 180,
                child: Column(
                  children: [_buildFabOption('Add Music'), _buildFabOption('Record Music')],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _isFabMenuOpen = !_isFabMenuOpen),
        backgroundColor: themeProvider.selectedColor,
        child: Icon(_isFabMenuOpen ? Icons.close : Icons.music_note, color: themeProvider.textColor, size: 28),
      ),
    );
  }

  Widget _buildFabOption(String title) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return ListTile(
      leading: Icon(title == 'Add Music' ? Icons.add : Icons.mic, color: themeProvider.selectedColor),
      title: Text(title, style: AppTextStyles.body),
      onTap: () async {
        setState(() => _isFabMenuOpen = false);
        if (title == 'Add Music') {
          if (await _requestPermissions()) {
            final newFile = await BellService().uploadMp3(context, null, isWifiConnected);
            if (newFile != null && mounted) _loadUploadedFiles();
          }
        } else {
          final micStatus = await Permission.microphone.status;
          if (!micStatus.isGranted) await Permission.microphone.request();
          final newRecordingPath = await Navigator.push<String>(
            context,
            MaterialPageRoute(builder: (context) => const AudioRecorderPage()),
          );
          if (newRecordingPath != null && mounted) _loadUploadedFiles();
        }
      },
    );
  }

  Widget _buildLibraryList() {
    if (apiSongs.isEmpty) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: apiSongs.length,
        itemBuilder: (context, index) {
          final song = apiSongs[index];
          final isPlaying = currentlyPlayingApiSong == song;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(width: 50, height: 50, color: Colors.red[200], child: const Icon(Icons.music_note, color: Colors.white)),
              ),
              title: Text(song, style: AppTextStyles.body),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.orange, size: 36),
                    onPressed: () => isPlaying ? _pauseApiSong() : _playApiSong(song),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteApiSong(song),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyMusicList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (recordings.isEmpty) {
      return Center(child: Text('No recordings yet.\nTap the + button to record something!', textAlign: TextAlign.center, style: AppTextStyles.body));
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
            background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
            onDismissed: (_) => _deleteRecording(index, filePath),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/Music.jpg', width: 50, height: 50, fit: BoxFit.cover),
                ),
                title: Text(fileName, style: AppTextStyles.body),
                subtitle: Text('00:00', style: AppTextStyles.small),
                trailing: Icon(_currentlyPlayingIndex == index && _player?.playing == true ? Icons.pause_circle_filled : Icons.play_circle_fill, color: themeProvider.selectedColor, size: 30),
                onTap: () => _playRecording(index),
              ),
            ),
          );
        },
      ),
    );
  }
}
