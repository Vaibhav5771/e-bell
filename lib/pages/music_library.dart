import 'dart:async';

import 'package:flutter/material.dart';
import 'package:e_bell/music_tabs/addmusic.dart';
import 'package:e_bell/music_tabs/recordingpage.dart';
import 'package:e_bell/pages/tablogic1.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:e_bell/services/bell_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

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

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _startWifiMonitoring();
  }

  @override
  void dispose() {
    wifiCheckTimer?.cancel();
    super.dispose();
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
                content: Text("Audio permission denied; cannot access MP3 files")),
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
        debugPrint("Raw Wi-Fi SSID: $wifiSSID"); // Log raw SSID
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

  @override
  Widget build(BuildContext context) {
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
                                print("Switching to Library tab");
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
                                print("Switching to My Music tab");
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
        backgroundColor: const Color.fromRGBO(255, 152, 0, 1),
        shape: const CircleBorder(),
        child: Icon(
          _isFabMenuOpen ? Icons.close : Icons.music_note,
          size: 28,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFabOption(String title, bool isChecked) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          setState(() => _isFabMenuOpen = false);
          switch (title) {
            case 'Add Music':
              await BellService().uploadMp3(context, isWifiConnected);
              setState(() {});
              break;
            case 'Record Music':
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const RecordMusicPage()),
              );
              setState(() {});
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
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Your Music'),
        _buildMyMusicList(),
      ],
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
          return Container(
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
          );
        },
      ),
    );
  }

  Widget _buildTrendingList() {
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
              trailing: const Icon(
                Icons.play_circle_fill,
                color: Colors.orange,
                size: 30,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyMusicList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
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
              trailing: const Icon(
                Icons.play_circle_fill,
                color: Colors.orange,
                size: 30,
              ),
              onTap: () {},
            ),
          );
        },
      ),
    );
  }
}