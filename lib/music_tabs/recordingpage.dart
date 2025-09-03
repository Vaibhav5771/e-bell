import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:e_bell/services/bell_service.dart';
import 'dart:async';

class AudioRecorderPage extends StatefulWidget {
  const AudioRecorderPage({super.key});

  @override
  _AudioRecorderPageState createState() => _AudioRecorderPageState();
}

class _AudioRecorderPageState extends State<AudioRecorderPage> {
  FlutterSoundRecorder? _recorder;
  AudioPlayer? _player;
  bool _isRecording = false;
  bool _isConverting = false;
  bool _isPlaying = false;
  bool _isLooping = false;
  String? _filePath;
  String? _mp3FilePath;
  String? _errorMessage;
  bool _micPermissionsGranted = false;
  bool _wifiPermissionsGranted = false;
  bool _isCheckingPermissions = false;
  String _connectionStatus = "Checking Wi-Fi...";
  bool _isWifiConnected = false;
  Timer? _wifiCheckTimer;
  final String _targetSsid = "IoGen_Speaker";

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = AudioPlayer();
    _initRecorder();
    _initPlayer();
    _requestPermissions();
    _startWifiMonitoring();
  }

  @override
  void dispose() {
    _recorder?.stopRecorder();
    _recorder?.closeRecorder();
    _recorder = null;
    _player?.stop();
    _player?.dispose();
    _player = null;
    _wifiCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _initRecorder() async {
    try {
      await _recorder?.openRecorder();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize recorder: $e';
      });
    }
  }

  Future<void> _initPlayer() async {
    try {
      _player?.playerStateStream.listen((state) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            if (_isLooping) {
              _player?.seek(Duration.zero);
              _player?.play();
            }
          }
        });
      }, onError: (e) {
        setState(() {
          _errorMessage = 'Playback error: $e';
          _isPlaying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback error: $e')),
        );
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize player: $e';
      });
    }
  }

  Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    return deviceInfo.version.sdkInt >= 33;
  }

  Future<void> _requestPermissions({bool wifiOnly = false}) async {
    if (_isCheckingPermissions) return;

    setState(() {
      _isCheckingPermissions = true;
      _errorMessage = null;
    });

    try {
      if (!wifiOnly) {
        // Request microphone and storage/audio permissions
        final isAndroid13Plus = await _isAndroid13OrHigher();
        final micPermissions = isAndroid13Plus
            ? [Permission.microphone, Permission.audio]
            : [Permission.microphone, Permission.storage];

        final micStatuses = await micPermissions.request();
        final micAllGranted = micStatuses.values.every((s) => s.isGranted);
        final micPermanentlyDenied = micStatuses.values.any((s) => s.isPermanentlyDenied);

        setState(() {
          _micPermissionsGranted = micAllGranted;
          if (!micAllGranted) {
            _errorMessage = micPermanentlyDenied
                ? 'Microphone permissions permanently denied. Please enable them in app settings.'
                : 'Microphone permissions not granted';
          }
        });

        if (micPermanentlyDenied) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPermissionDialog('Microphone');
          });
        }

        if (!micAllGranted) return;
      }

      // Request location permission for Wi-Fi
      final locationStatus = await Permission.location.request();
      final locationGranted = locationStatus.isGranted;
      final locationPermanentlyDenied = locationStatus.isPermanentlyDenied;

      // Request nearbyWifiDevices only for Android 13+
      bool wifiDevicesGranted = true;
      if (await _isAndroid13OrHigher()) {
        final wifiDevicesStatus = await Permission.nearbyWifiDevices.request();
        wifiDevicesGranted = wifiDevicesStatus.isGranted;
        if (wifiDevicesStatus.isPermanentlyDenied) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPermissionDialog('Nearby Wi-Fi Devices');
          });
        }
      }

      setState(() {
        _wifiPermissionsGranted = locationGranted && wifiDevicesGranted;
        if (!locationGranted) {
          _errorMessage = locationPermanentlyDenied
              ? 'Location permission permanently denied. Please enable in app settings.'
              : 'Location permission not granted';
        } else if (!wifiDevicesGranted) {
          _errorMessage = 'Nearby Wi-Fi devices permission not granted';
        }
      });

      if (locationPermanentlyDenied || (!wifiDevicesGranted && await _isAndroid13OrHigher())) {
        return;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Permission request failed: $e';
      });
    } finally {
      setState(() {
        _isCheckingPermissions = false;
      });
    }
  }

  void _showPermissionDialog(String permissionType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$permissionType Permission Required'),
          content: Text(
            'This app needs $permissionType permission to function properly. Please grant it in app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startWifiMonitoring() async {
    await _checkWifiConnection();
    _wifiCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkWifiConnection();
    });
  }

  Future<void> _checkWifiConnection() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        String? wifiSSID = await NetworkInfo().getWifiName();
        String? cleanedSSID = wifiSSID?.replaceAll('"', '').trim();
        debugPrint('Raw Wi-Fi SSID: $wifiSSID');
        debugPrint('Cleaned Wi-Fi SSID: $cleanedSSID');
        setState(() {
          _isWifiConnected = true;
          if (cleanedSSID != null && cleanedSSID.toLowerCase() == _targetSsid.toLowerCase()) {
            _connectionStatus = 'Connected to $_targetSsid';
          } else {
            _connectionStatus = 'Connected to Wi-Fi: ${cleanedSSID ?? 'Unknown'}';
          }
        });
      } else {
        setState(() {
          _isWifiConnected = false;
          _connectionStatus = 'Not connected to Wi-Fi';
        });
      }
    } catch (e) {
      setState(() {
        _isWifiConnected = false;
        _connectionStatus = 'Error checking Wi-Fi: $e';
      });
      debugPrint('Wi-Fi check error: $e');
    }
  }

  Future<void> _startRecording() async {
    await _requestPermissions();

    final directory = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${directory.path}/recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    _filePath = '${recordingsDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.aac';

    try {
      await _recorder?.startRecorder(
        toFile: _filePath,
        codec: Codec.aacADTS,
      );
      setState(() {
        _isRecording = true;
        _errorMessage = null;
        _mp3FilePath = null;
        _isPlaying = false;
        _isLooping = false;
      });
      await _player?.stop();
    } catch (e) {
      setState(() {
        _errorMessage = 'Recording failed: $e';
      });
    }
  }

  Future<String?> _convertAACtoMP3(String inputPath) async {
    setState(() {
      _isConverting = true;
      _errorMessage = null;
    });

    try {
      final outputPath = inputPath.replaceAll('.aac', '.mp3');
      final command = '-i "$inputPath" -c:a mp3 -b:a 128k "$outputPath"';
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        try {
          final aacFile = File(inputPath);
          if (await aacFile.exists()) {
            await aacFile.delete();
          }
        } catch (e) {
          debugPrint('Error deleting AAC file: $e');
        }
        return outputPath;
      } else {
        final logs = await session.getOutput();
        setState(() {
          _errorMessage = 'Conversion failed: $logs';
        });
        return null;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Conversion error: $e';
      });
      return null;
    } finally {
      setState(() {
        _isConverting = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder?.stopRecorder();
      setState(() {
        _isRecording = false;
      });

      if (_filePath != null) {
        final mp3FilePath = await _convertAACtoMP3(_filePath!);
        if (mp3FilePath != null && mounted) {
          setState(() {
            _mp3FilePath = mp3FilePath;
          });
          await _player?.setFilePath(mp3FilePath);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to convert recording')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No recording found')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to stop recording: $e';
      });
    }
  }

  Future<void> _playPauseRecording() async {
    try {
      if (_mp3FilePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No recording available to play')),
        );
        return;
      }

      if (_isPlaying) {
        await _player?.pause();
      } else {
        await _player?.seek(Duration.zero);
        await _player?.play();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Playback error: $e';
        _isPlaying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playback error: $e')),
      );
    }
  }

  Future<void> _toggleLooping() async {
    setState(() {
      _isLooping = !_isLooping;
    });
    await _player?.setLoopMode(_isLooping ? LoopMode.one : LoopMode.off);
  }

  Future<void> _saveAndUpload() async {
    if (_mp3FilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recording to save or upload')),
      );
      return;
    }

    try {
      final file = File(_mp3FilePath!);
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording file not found')),
        );
        return;
      }

      debugPrint('Starting upload for file: $_mp3FilePath');

      // Check Wi-Fi permissions
      if (!_wifiPermissionsGranted) {
        await _requestPermissions(wifiOnly: true);
        if (!_wifiPermissionsGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wi-Fi permissions required for upload.')),
          );
          return;
        }
      }

      // Check Wi-Fi SSID
      if (!_isWifiConnected || !_connectionStatus.contains(_targetSsid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please connect to IoGen_Speaker Wi-Fi for upload.')),
        );
        return;
      }

      final bellService = BellService();
      final uploadedPath = await bellService.uploadMp3(context, _mp3FilePath, _isWifiConnected);
      debugPrint('Upload result: $uploadedPath');

      if (uploadedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording saved and uploaded successfully')),
        );
        Navigator.pop(context, uploadedPath);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload recording')),
        );
      }
    } catch (e) {
      debugPrint('Save/Upload error: $e');
      setState(() {
        _errorMessage = 'Save/Upload error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save/Upload error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text(
          'Record Audio',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isConverting)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Converting to MP3...'),
                ],
              )
            else
              Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                size: 80,
                color: _isRecording ? Colors.orange : Colors.grey[400],
              ),
            const SizedBox(height: 20),
            Text(
              _isRecording
                  ? 'Recording...'
                  : _mp3FilePath != null
                  ? 'Recording Ready: ${_mp3FilePath!.split('/').last}'
                  : 'Ready to record',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _isRecording ? Colors.orange : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              _connectionStatus,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 30),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _isConverting
                      ? null
                      : _isRecording
                      ? _stopRecording
                      : _startRecording,
                  child: Text(
                    _isRecording ? 'Stop Recording' : 'Start Recording',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                if (_mp3FilePath != null && !_isRecording && !_isConverting) ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _playPauseRecording,
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isLooping ? Colors.purple : Colors.grey,
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _toggleLooping,
                    child: Icon(
                      Icons.loop,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _saveAndUpload,
                    child: const Text(
                      'Save & Upload',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}