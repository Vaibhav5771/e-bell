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
import 'package:e_bell/music_tabs/recordingpage.dart';
import 'package:e_bell/pages/tablogic1.dart';
import 'package:e_bell/services/bell_service.dart';
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
      debugPrint("AudioPlayer initialized successfully");
    } catch (e) {
      debugPrint('Failed to initialize player: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize player: $e')),
        );
      }
    }
  }

  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidVersion();
      if (androidVersion >= 33) {
        final audioStatus = await Permission.audio.status;
        if (!audioStatus.isGranted) {
          return (await Permission.audio.request()).isGranted;
        }
        return true;
      } else {
        final storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          return (await Permission.storage.request()).isGranted;
        }
        return true;
      }
    }
    return true;
  }

  Future<void> _loadRecordings() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = await directory.list().toList();
    debugPrint("Documents directory: ${directory.path}");
    debugPrint("Found files: ${files.map((f) => f.path).toList()}");

    final existingPaths = recordings.toSet();
    final newRecordings = files
        .where((file) => file is File && (file.path.toLowerCase().endsWith('.wav') || file.path.toLowerCase().endsWith('.mp3')))
        .map((file) => file.path)
        .where((path) => !existingPaths.contains(path))
        .toList();

    setState(() {
      recordings.addAll(newRecordings);
      _isLoading = false;
      debugPrint("Updated recordings: $recordings");
    });
  }

  Future<void> _playRecording(int index) async {
    try {
      final filePath = recordings[index];
      final file = File(filePath);
      debugPrint("Attempting to play: $filePath");

      if (!await file.exists()) {
        debugPrint("File does not exist: $filePath");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File not found: $filePath')),
          );
        }
        return;
      }

      if (_currentlyPlayingIndex == index && _player?.playing == true) {
        await _player?.pause();
        setState(() {
          debugPrint("Paused audio: $filePath");
        });
        return;
      }

      if (_currentlyPlayingIndex == index && _player?.playing == false) {
        await _player?.play();
        setState(() {
          debugPrint("Resumed audio: $filePath");
        });
        return;
      }

      await _player?.stop();
      _playerStateSubscription?.cancel();

      await _player?.setFilePath(filePath);
      await _player?.play();

      _playerStateSubscription = _player?.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          debugPrint("Playback finished for: $filePath");
          setState(() {
            _currentlyPlayingIndex = null;
          });
        }
      }, onError: (e) {
        debugPrint("Playback error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Playback error: $e')),
          );
        }
        setState(() {
          _currentlyPlayingIndex = null;
        });
      });

      setState(() {
        _currentlyPlayingIndex = index;
      });
    } catch (e) {
      debugPrint('Error playing audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
      setState(() {
        _currentlyPlayingIndex = null;
      });
    }
  }

  Future<void> _deleteRecording(int index, String filePath) async {
    final file = File(filePath);
    final fileName = file.uri.pathSegments.last;

    try {
      if (fileName.toLowerCase().endsWith('.mp3')) {
        final url = Uri.parse('http://192.168.2.1/delete/$fileName');
        final response = await HttpClient().deleteUrl(url).then((req) => req.close());

        if (response.statusCode != 200) {
          debugPrint("Failed to delete on device: ${response.statusCode}");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Device deletion failed: ${response.statusCode}')),
            );
          }
        } else {
          debugPrint("Deleted on IoT device: $fileName");
        }
      }

      await file.delete();
      debugPrint("Deleted locally: $filePath");
    } catch (e) {
      debugPrint("Error during delete: $e");
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
        debugPrint("Raw Wi-Fi SSID: $wifiSSID");
        setState(() {
          isWifiConnected = true;
          if (wifiSSID != null &&
              wifiSSID.toLowerCase() == targetSsid.toLowerCase()) {
            connectionStatus = "Connected to $targetSsid";
          } else {
            connectionStatus = "Connected to Wi-Fi: ${wifiSSID ?? 'Unknown'}";
          }
        });
        debugPrint("Connection Status: $connectionStatus");
      } else {
        setState(() {
          isWifiConnected = false;
          connectionStatus = "Not connected to Wi-Fi";
        });
        debugPrint("Not connected to Wi-Fi");
      }
    } catch (e) {
      setState(() {
        isWifiConnected = false;
        connectionStatus = "Error checking Wi-Fi: $e";
      });
      debugPrint("Error checking Wi-Fi: $e");
    }
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses;

    if (Platform.isAndroid) {
      if ((await _getAndroidVersion()) >= 33) {
        statuses = await [
          Permission.location,
          Permission.nearbyWifiDevices,
          Permission.audio,
        ].request();
      } else {
        statuses = await [
          Permission.location,
          Permission.nearbyWifiDevices,
          Permission.storage,
        ].request();
      }
    } else {
      statuses = await [
        Permission.location,
        Permission.nearbyWifiDevices,
      ].request();
    }

    if (statuses[Permission.location]!.isDenied) {
      setState(() {
        connectionStatus = "Location permission denied";
      });
      debugPrint("Location permission denied");
    } else {
      debugPrint("Location permission granted");
    }

    if (Platform.isAndroid) {
      if ((await _getAndroidVersion()) >= 33) {
        if (statuses[Permission.audio]!.isDenied) {
          debugPrint("Audio permission denied");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Audio permission denied; cannot access audio files")),
          );
        } else {
          debugPrint("Audio permission granted");
        }
      } else {
        if (statuses[Permission.storage]!.isDenied) {
          debugPrint("Storage permission denied");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Storage permission denied; cannot access files")),
          );
        } else {
          debugPrint("Storage permission granted");
        }
      }
    }
  }

  Future<int> _getAndroidVersion() async {
    try {
      if (Platform.isAndroid) {
        var version = await DeviceInfoPlugin().androidInfo;
        return version.version.sdkInt;
      }
    } catch (e) {
      debugPrint("Error getting Android version: $e");
    }
    return 0;
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
                              onTap: () {
                                setState(() {
                                  widget.tabLogic.setSelectedTab(0);
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: widget.tabLogic.buildTab(
                              context: context,
                              text: 'My Music',
                              index: 1,
                              onTap: () {
                                setState(() {
                                  widget.tabLogic.setSelectedTab(1);
                                });
                              },
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
                    _buildFabOption('Add Music', false),
                    _buildFabOption('Record Music', false),
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

  Widget _buildFabOption(String title, bool isChecked) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          setState(() => _isFabMenuOpen = false);
          switch (title) {
            case 'Add Music':
              if (await _checkPermissions()) {
                debugPrint("Before upload, recordings: $recordings");
                final newFilePath = await BellService().uploadMp3(context, null, isWifiConnected);
                if (newFilePath != null) {
                  setState(() {
                    recordings.add(newFilePath);
                    debugPrint("Added to recordings: $newFilePath");
                    debugPrint("After upload, recordings: $recordings");
                    widget.tabLogic.setSelectedTab(1); // Switch to My Music tab
                  });
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Required permissions not granted")),
                );
              }
              break;
            case 'Record Music':
              final newRecordingPath = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (context) => const AudioRecorderPage(),
                ),
              );
              if (newRecordingPath != null) {
                setState(() {
                  recordings.add(newRecordingPath);
                  debugPrint("Added recording: $newRecordingPath");
                  debugPrint("After recording, recordings: $recordings");
                  widget.tabLogic.setSelectedTab(1); // Switch to My Music tab
                });
              }
              break;
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: themeProvider.selectedColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  color: themeProvider.textColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
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
          style: TextStyle(fontSize: 16),
        ),
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
          final file = File(filePath);
          final fileName = file.path.split('/').last;
          return Dismissible(
            key: Key(filePath), // Unique key based on file path
            onDismissed: (direction) {
              debugPrint("Dismissed item at index $index: $filePath");
              setState(() {
                recordings.removeAt(index);
                if (_currentlyPlayingIndex != null && _currentlyPlayingIndex! >= index) {
                  if (_currentlyPlayingIndex == index) {
                    _currentlyPlayingIndex = null;
                    _player?.stop();
                    _playerStateSubscription?.cancel();
                  } else {
                    _currentlyPlayingIndex = _currentlyPlayingIndex! - 1;
                  }
                  debugPrint("Updated _currentlyPlayingIndex: $_currentlyPlayingIndex");
                }
                debugPrint("Remaining recordings: $recordings");
              });
              _deleteRecording(index, filePath);
            },
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
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
                subtitle: const Text('00:00'), // Placeholder; update with actual duration if needed
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ComingSoonPage(),
                ),
              );
            },
            child: Material(
              borderRadius: BorderRadius.circular(12),
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