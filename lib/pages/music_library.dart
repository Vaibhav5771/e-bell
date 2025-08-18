import 'dart:async';
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
import 'package:e_bell/pages/tablogic1.dart';
import 'package:e_bell/services/bell_service.dart';
import '../music_tabs/recordingpage.dart';
import '../services/theme_state.dart';
import 'comingsoon.dart';

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
  List<String> recordings = [];
  bool _isLoading = true;
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
    _loadRecordings();
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

  Future<void> _initPlayer() async {
    try {
      _playerStateSubscription = _player?.playerStateStream.listen((state) {
        setState(() {
          if (state.processingState == ProcessingState.completed) {
            _currentlyPlayingIndex = null;
          }
        });
      }, onError: (e) {
        debugPrint("Player state stream error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Playback error: $e')),
          );
        }
        setState(() {
          _currentlyPlayingIndex = null;
        });
      });
    } catch (e) {
      debugPrint('Failed to initialize player: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize player: $e')),
        );
      }
    }
  }

  Future<void> _loadRecordings() async {
    try {
      setState(() => _isLoading = true);

      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');

      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final files = await recordingsDir.list().toList();

      final mp3Files = files
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.mp3'))
          .toList();

      mp3Files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      setState(() {
        recordings = mp3Files.map((file) => file.path).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading recordings: $e')),
        );
      }
    }
  }

  Future<void> _playRecording(int index) async {
    try {
      final filePath = recordings[index];
      final file = File(filePath);

      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File not found: ${file.path}')),
          );
        }
        return;
      }

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
      debugPrint('Error playing audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
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
          const SnackBar(content: Text('Recording deleted')),
        );
      }
    } catch (e) {
      debugPrint("Error deleting file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting file: $e')),
        );
      }
    }
  }

  Future<void> _startWifiMonitoring() async {
    await _checkWifiConnection();
    wifiCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkWifiConnection();
    });
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

  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidVersion();
      if (androidVersion >= 33) {
        return (await Permission.audio.request()).isGranted;
      } else {
        return (await Permission.storage.request()).isGranted;
      }
    }
    return true;
  }

  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      var version = await DeviceInfoPlugin().androidInfo;
      return version.version.sdkInt;
    }
    return 0;
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      if ((await _getAndroidVersion()) >= 33) {
        await [
          Permission.location,
          Permission.nearbyWifiDevices,
          Permission.audio,
          Permission.microphone,
        ].request();
      } else {
        await [
          Permission.location,
          Permission.nearbyWifiDevices,
          Permission.storage,
          Permission.microphone,
        ].request();
      }
    } else {
      await [
        Permission.location,
        Permission.nearbyWifiDevices,
        Permission.microphone,
      ].request();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          Column(
            children: [
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
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                    Text(
                      connectionStatus,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: widget.tabLogic.selectedTabIndex == 0
                      ? _buildLibraryContent()
                      : _buildMyMusicContent(),
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
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildFabOption('Add Music'),
                    _buildFabOption('Record Music'),
                  ],
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
        shape: const CircleBorder(
          side: BorderSide(
            color: Colors.transparent,
          ),
        ),
        child: Icon(
          _isFabMenuOpen ? Icons.close : Icons.music_note,
          size: 28,
          color: themeProvider.textColor,
        ),
      ),
    );
  }

  Widget _buildFabOption(String title) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return ListTile(
      leading: Icon(
        title == 'Add Music' ? Icons.add : Icons.mic,
        color: themeProvider.selectedColor,
      ),
      title: Text(title),
      onTap: () async {
        setState(() => _isFabMenuOpen = false);
        if (title == 'Add Music') {
          if (await _checkPermissions()) {
            final newFilePath = await BellService().uploadMp3(context, null, isWifiConnected);
            if (newFilePath != null && mounted) {
              await _loadRecordings();
              widget.tabLogic.setSelectedTab(1);
            }
          }
        } else {
          final micStatus = await Permission.microphone.status;
          if (!micStatus.isGranted) {
            final result = await Permission.microphone.request();
            if (!result.isGranted) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Microphone permission required')),
                );
              }
              return;
            }
          }

          final newRecordingPath = await Navigator.push<String>(
            context,
            MaterialPageRoute(builder: (context) => const AudioRecorderPage()),
          );

          if (newRecordingPath != null && mounted) {
            await _loadRecordings();
            widget.tabLogic.setSelectedTab(1);
          }
        }
      },
    );
  }

  Widget _buildLibraryContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Category'),
        _buildCategoryGrid(),
        _buildSectionTitle('Trending Music'),
        _buildTrendingList(),
      ],
    );
  }

  Widget _buildMyMusicContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (recordings.isEmpty) {
      return const Center(
        child: Text(
            'No recordings yet.\nTap the + button to record something!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16)),
      );
    }

    return _buildMyMusicList();
  }

  Widget _buildMyMusicList() {
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
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (direction) {
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
              _deleteRecording(index, filePath);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/Music.jpg',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(fileName),
                subtitle: const Text('00:00'),
                trailing: Icon(
                  _currentlyPlayingIndex == index && _player?.playing == true
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: themeProvider.selectedColor,
                  size: 30,
                ),
                onTap: () => _playRecording(index),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ComingSoonPage()),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: const DecorationImage(
                  image: AssetImage('assets/Music.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Category',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendingList() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 2,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/Music.jpg',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text('Song ${index + 1}'),
              subtitle: const Text('00:00'),
              trailing: Icon(
                Icons.play_circle_fill,
                color: themeProvider.selectedColor,
                size: 30,
              ),
            ),
          );
        },
      ),
    );
  }
}