import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../music_tabs/recordingpage.dart';
import '../services/services.dart';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';
import '../utils/quickalert.dart';
import 'tablogic1.dart';

class MusicLibrary extends StatefulWidget {
  final TabLogic1 tabLogic;
  const MusicLibrary({super.key, required this.tabLogic});

  @override
  _MusicLibraryState createState() => _MusicLibraryState();
}

class _MusicLibraryState extends State<MusicLibrary> {
  bool _isFabMenuOpen = false;

  // Wi-Fi
  bool isWifiConnected = false;
  String connectionStatus = "Checking Wi-Fi...";
  Timer? wifiCheckTimer;
  final String targetSsid = "IoGen_Speaker";

  // Local recordings
  List<String> recordings = [];
  bool _isLoading = true;

  // Songs uploaded to device API
  List<String> apiSongs = [];
  String? currentlyPlayingApiSong;

  // Audio Player
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
    super.dispose();
  }

  // AUDIO PLAYER INIT
  Future<void> _initPlayer() async {
    _playerStateSubscription = _player?.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        if (state.processingState == ProcessingState.completed) {
          _currentlyPlayingIndex = null;
          currentlyPlayingApiSong = null;
        }
      });
    });
  }

  // LOAD LOCAL + API SONGS
  Future<void> _loadUploadedFiles() async {
    setState(() => _isLoading = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final recDir = Directory('${dir.path}/recordings');

      if (!await recDir.exists()) {
        await recDir.create(recursive: true);
      }

      final files = await recDir.list().toList();
      final mp3Files = files.whereType<File>().where((f) {
        return f.path.toLowerCase().endsWith('.mp3');
      }).toList();

      mp3Files.sort((a, b) {
        return b.statSync().modified.compareTo(a.statSync().modified);
      });

      final localRecordings = mp3Files.map((f) => f.path).toList();

      // FETCH API FILES
      final bellService = BellService();
      final uploadedFiles = await bellService.fetchSoundFiles(context);

      if (!mounted) return;

      setState(() {
        recordings = localRecordings;
        apiSongs = uploadedFiles;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppAlert.error(context, text: "Error loading files: $e");
    }
  }

  // PLAY LOCAL FILE
  Future<void> _playRecording(int index) async {
    try {
      final filePath = recordings[index];
      final file = File(filePath);

      if (!await file.exists()) return;

      if (_currentlyPlayingIndex == index && _player!.playing) {
        await _player!.pause();
        return;
      }

      if (_currentlyPlayingIndex == index && !_player!.playing) {
        await _player!.play();
        return;
      }

      await _player!.stop();
      setState(() => _currentlyPlayingIndex = index);

      await _player!.setFilePath(filePath);
      await _player!.play();
    } catch (e) {
      if (!mounted) return;
      AppAlert.error(context, text: "Error playing audio: $e");
    }
  }

  // DELETE LOCAL FILE
  Future<void> _deleteRecording(int index, String filePath) async {
    try {
      final file = File(filePath);
      await file.delete();

      setState(() {
        recordings.removeAt(index);
        if (_currentlyPlayingIndex == index) {
          _player?.stop();
          _currentlyPlayingIndex = null;
        }
      });

      AppAlert.success(context, text: "Recording deleted");
    } catch (e) {
      AppAlert.error(context, text: "Delete error: $e");
    }
  }

  // FETCH SONGS FROM IOT DEVICE
  Future<void> _fetchApiSongs() async {
    try {
      final response =
      await http.get(Uri.parse("http://192.168.2.1/alarmsong/"));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List<dynamic> files = jsonResponse["Data"][0]["files"];

        if (!mounted) return;

        setState(() {
          apiSongs = files.map((e) => e[0].toString()).toList();
        });
      }
    } catch (e) {
      debugPrint("Fetch API songs error: $e");
    }
  }

  // PLAY SONG FROM DEVICE
  Future<void> _playApiSong(String name) async {
    try {
      await http.post(Uri.parse("http://192.168.2.1/preview/"), body: "0");
      await Future.delayed(const Duration(milliseconds: 200));

      final response = await http.post(
        Uri.parse("http://192.168.2.1/preview/"),
        body: "1,$name",
      );

      if (response.statusCode == 200 && mounted) {
        _player?.stop();
        setState(() {
          currentlyPlayingApiSong = name;
          _currentlyPlayingIndex = null;
        });
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, text: "Error playing: $e");
      }
    }
  }

  // PAUSE API SONG
  Future<void> _pauseApiSong() async {
    try {
      await http.post(Uri.parse("http://192.168.2.1/preview/"), body: "0");
      if (mounted) setState(() => currentlyPlayingApiSong = null);
    } catch (_) {}
  }

  // DELETE API SONG
  Future<void> _deleteApiSong(String fileName) async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Delete"),
          content: Text("Delete $fileName?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);

                try {
                  final body = "$fileName,0,0,0,0,0";
                  final response = await http.post(
                    Uri.parse("http://192.168.2.1/delete/"),
                    body: body,
                  );

                  if (response.statusCode == 200 && mounted) {
                    setState(() {
                      apiSongs.remove(fileName);
                    });
                    AppAlert.success(context, text: "Deleted");
                  }
                } catch (_) {}
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            )
          ],
        );
      },
    );
  }

  // WIFI CHECK
  Future<void> _startWifiMonitoring() async {
    await _checkWifiConnection();
    wifiCheckTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _checkWifiConnection());
  }

  Future<void> _checkWifiConnection() async {
    try {
      var result = await Connectivity().checkConnectivity();

      if (result.contains(ConnectivityResult.wifi)) {
        String? wifiSSID = await NetworkInfo().getWifiName();
        setState(() {
          isWifiConnected = wifiSSID?.toLowerCase() == targetSsid.toLowerCase();
          connectionStatus = isWifiConnected
              ? "Connected to IoGen_Speaker"
              : "Connected to ${wifiSSID ?? 'Unknown'}";
        });
      } else {
        setState(() {
          isWifiConnected = false;
          connectionStatus = "Not connected to WiFi";
        });
      }
    } catch (e) {
      setState(() => connectionStatus = "Error: $e");
    }
  }

  // PERMISSIONS
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final androidVersion = await DeviceInfoPlugin().androidInfo;

      if (androidVersion.version.sdkInt >= 33) {
        final result = await [
          Permission.location,
          Permission.microphone,
          Permission.nearbyWifiDevices
        ].request();

        return result.values.every((e) => e.isGranted);
      } else {
        final result = await [
          Permission.location,
          Permission.microphone,
          Permission.storage,
          Permission.nearbyWifiDevices
        ].request();

        return result.values.every((e) => e.isGranted);
      }
    }

    final result = await [
      Permission.location,
      Permission.microphone,
    ].request();

    return result.values.every((e) => e.isGranted);
  }

  // ---------------- UI ------------------
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          const SizedBox(height: 20),
          Text(connectionStatus, style: AppTextStyles.body),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: widget.tabLogic.selectedTabIndex == 0
                  ? _buildLibraryList()
                  : _buildMyMusicList(),
            ),
          ),
        ],
      ),

      // FAB
      floatingActionButton: FloatingActionButton(
        backgroundColor: themeProvider.selectedColor,
        shape: const CircleBorder(),
        child: Icon(
          _isFabMenuOpen ? Icons.close : Icons.music_note,
          color: Colors.white,
        ),
        onPressed: () {
          setState(() => _isFabMenuOpen = !_isFabMenuOpen);
        },
      ),

      // FAB MENU
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // FAB menu options
  Widget _buildFabOption(String title) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return ListTile(
      leading: Icon(
        title == "Add Music" ? Icons.add : Icons.mic,
        color: themeProvider.selectedColor,
      ),
      title: Text(title),
      onTap: () async {
        setState(() => _isFabMenuOpen = false);

        if (title == "Add Music") {
          final granted = await _requestPermissions();
          if (!granted) {
            AppAlert.error(context, text: "Permission denied!");
            return;
          }

          await Future.delayed(const Duration(milliseconds: 250));

          final uploadedFile = await BellService().uploadMp3(
            context,
            null,
            isWifiConnected,
          );

          if (uploadedFile != null) {
            await _loadUploadedFiles();
            await _fetchApiSongs();
            AppAlert.success(context, text: "Music uploaded!");
          }
        } else {
          final micStatus = await Permission.microphone.status;
          if (!micStatus.isGranted) await Permission.microphone.request();

          if (await Permission.microphone.isGranted) {
            final newRecording = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (_) => const AudioRecorderPage()),
            );

            if (newRecording != null) {
              await _loadUploadedFiles();
              AppAlert.success(context, text: "Recording saved!");
            }
          }
        }
      },
    );
  }

  // API songs list
  Widget _buildLibraryList() {
    if (apiSongs.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: apiSongs.length,
      itemBuilder: (context, index) {
        final song = apiSongs[index];
        final isPlaying = currentlyPlayingApiSong == song;

        return ListTile(
          leading: const Icon(Icons.music_note),
          title: Text(song),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_circle : Icons.play_circle,
                  color: Colors.orange,
                ),
                onPressed: () {
                  isPlaying ? _pauseApiSong() : _playApiSong(song);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteApiSong(song),
              ),
            ],
          ),
        );
      },
    );
  }

  // LOCAL recordings list
  Widget _buildMyMusicList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (recordings.isEmpty) {
      return const Center(child: Text("No recordings found."));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recordings.length,
      itemBuilder: (context, index) {
        final filePath = recordings[index];
        final fileName = filePath.split('/').last;

        final isPlaying =
            _currentlyPlayingIndex == index && _player?.playing == true;

        return Dismissible(
          key: Key(filePath),
          onDismissed: (_) => _deleteRecording(index, filePath),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: ListTile(
            title: Text(fileName),
            subtitle: const Text("00:00"),
            leading: Image.asset(
              "assets/Music.jpg",
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
            trailing: Icon(
              isPlaying ? Icons.pause_circle : Icons.play_circle,
              color: Colors.blue,
            ),
            onTap: () => _playRecording(index),
          ),
        );
      },
    );
  }
}