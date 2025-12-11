import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:e_bell/services/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';

class AudioRecorderPage extends StatefulWidget {
  const AudioRecorderPage({super.key});

  @override
  _AudioRecorderPageState createState() => _AudioRecorderPageState();
}

class _AudioRecorderPageState extends State<AudioRecorderPage> {
  FlutterSoundRecorder? _recorder;
  AudioPlayer? _player;
  
  // State variables
  bool _isRecording = false;
  bool _isConverting = false;
  bool _isPlaying = false;
  bool _isLooping = false;
  
  // File paths and errors
  String? _filePath;
  String? _mp3FilePath;
  String? _errorMessage;
  
  // Permissions and Network
  bool _micPermissionsGranted = false;
  bool _wifiPermissionsGranted = false;
  bool _isCheckingPermissions = false;
  String _connectionStatus = "Checking Wi-Fi...";
  bool _isWifiConnected = false;
  Timer? _wifiCheckTimer;
  final String _targetSsid = "IoGen_Speaker";

  // Timers and Duration tracking
  Timer? _recordingLimitTimer;
  StreamSubscription? _recorderSubscription;
  Duration _currentDuration = Duration.zero;

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
    _recordingLimitTimer?.cancel();
    _recorderSubscription?.cancel();
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
      // crucial for the onProgress stream to fire updates every 100ms
      await _recorder?.setSubscriptionDuration(const Duration(milliseconds: 100));
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize recorder: $e';
      });
    }
  }

  /// Formats duration into MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Future<String?> _askForFileName(BuildContext context) async {
    final controller = TextEditingController();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Name this file',
            style: AppTextStyles.heading.copyWith(fontSize: 20),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: "Enter file name",
              hintStyle: AppTextStyles.body,
              prefixIcon: Icon(Icons.edit, color: themeProvider.selectedColor),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: themeProvider.selectedColor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: themeProvider.selectedColor, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(
                'Cancel',
                style: AppTextStyles.button.copyWith(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.selectedColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx, name);
                }
              },
              child: Text(
                'Save',
                style: AppTextStyles.button,
              ),
            ),
          ],
        );
      },
    );
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
          SnackBar(
            content: Text(
              'Playback error: $e',
              style: AppTextStyles.body,
            ),
          ),
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
        final isAndroid13Plus = await _isAndroid13OrHigher();
        final micPermissions = isAndroid13Plus
            ? [Permission.microphone, Permission.audio]
            : [Permission.microphone, Permission.storage];

        final micStatuses = await micPermissions.request();
        final micAllGranted = micStatuses.values.every((s) => s.isGranted);
        final micPermanentlyDenied =
            micStatuses.values.any((s) => s.isPermanentlyDenied);

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

      final locationStatus = await Permission.location.request();
      final locationGranted = locationStatus.isGranted;
      final locationPermanentlyDenied = locationStatus.isPermanentlyDenied;

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

      if (locationPermanentlyDenied ||
          (!wifiDevicesGranted && await _isAndroid13OrHigher())) {
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
          title: Text(
            '$permissionType Permission Required',
            style: AppTextStyles.heading,
          ),
          content: Text(
            'This app needs $permissionType permission to function properly. Please grant it in app settings.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: AppTextStyles.button.copyWith(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              child: Text(
                'Open Settings',
                style: AppTextStyles.button.copyWith(color: Colors.black),
              ),
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
          if (cleanedSSID != null &&
              cleanedSSID.toLowerCase() == _targetSsid.toLowerCase()) {
            _connectionStatus = 'Connected to $_targetSsid';
          } else {
            _connectionStatus =
                'Connected to Wi-Fi: ${cleanedSSID ?? 'Unknown'}';
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

    _filePath =
        '${recordingsDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.aac';

    try {
      await _recorder?.startRecorder(
        toFile: _filePath,
        codec: Codec.aacADTS,
      );

      // 🎤 Start listening to the progress stream
      _recorderSubscription = _recorder?.onProgress?.listen((e) {
        if (mounted) {
          setState(() {
            _currentDuration = e.duration;
          });
        }
      });
      
      setState(() {
        _isRecording = true;
        _errorMessage = null;
        _mp3FilePath = null;
        _isPlaying = false;
        _isLooping = false;
        _currentDuration = Duration.zero; // Reset display
      });
      
      await _player?.stop();

      // Start the 60-second timer
      _recordingLimitTimer?.cancel(); 
      _recordingLimitTimer = Timer(const Duration(seconds: 60), () {
        if (mounted && _isRecording) {
          _stopRecording(isTimeLimit: true);
        }
      });

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

  Future<void> _stopRecording({bool isTimeLimit = false}) async {
    // Stop timers and listeners
    _recordingLimitTimer?.cancel();
    _recorderSubscription?.cancel();
    _recorderSubscription = null;
    
    // Optional: Reset duration or keep it to show final length
    // setState(() { _currentDuration = Duration.zero; });

    try {
      await _recorder?.stopRecorder();
      setState(() {
        _isRecording = false;
      });

      // Show Popup if time limit was reached
      if (isTimeLimit && mounted) {
         await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Limit Exceeded"),
            content: const Text("Recording stopped automatically because it reached the 60-second limit."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK", style: TextStyle(color: Colors.blue)),
              )
            ],
          ),
        );
      }

      if (_filePath != null) {
        final mp3FilePath = await _convertAACtoMP3(_filePath!);
        if (mp3FilePath != null && mounted) {
          final customName = await _askForFileName(context);
          if (customName != null && customName.isNotEmpty) {
            final file = File(mp3FilePath);
            final newPath = file.parent.path + '/$customName.mp3';
            await file.rename(newPath);

            setState(() {
              _mp3FilePath = newPath;
            });
            await _player?.setFilePath(newPath);
          } else {
            setState(() {
              _mp3FilePath = mp3FilePath;
            });
            await _player?.setFilePath(mp3FilePath);
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to convert recording',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No recording found',
              style: AppTextStyles.body,
            ),
          ),
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
          SnackBar(
            content: Text(
              'No recording available to play',
              style: AppTextStyles.body,
            ),
          ),
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
        SnackBar(
          content: Text(
            'Playback error: $e',
            style: AppTextStyles.body,
          ),
        ),
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
        SnackBar(
          content: Text(
            'No recording to save or upload',
            style: AppTextStyles.body,
          ),
        ),
      );
      return;
    }

    try {
      final file = File(_mp3FilePath!);
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recording file not found',
              style: AppTextStyles.body,
            ),
          ),
        );
        return;
      }

      debugPrint('Starting upload for file: $_mp3FilePath');

      if (!_wifiPermissionsGranted) {
        await _requestPermissions(wifiOnly: true);
        if (!_wifiPermissionsGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Wi-Fi permissions required for upload.',
                style: AppTextStyles.body,
              ),
            ),
          );
          return;
        }
      }

      if (!_isWifiConnected || !_connectionStatus.contains(_targetSsid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please connect to IoGen_Speaker Wi-Fi for upload.',
              style: AppTextStyles.body,
            ),
          ),
        );
        return;
      }

      // Start the upload but don't wait for response - navigate immediately
      _startUploadAndNavigate(_mp3FilePath!);

    } catch (e) {
      debugPrint('Save/Upload error: $e');
      setState(() {
        _errorMessage = 'Save/Upload error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Save/Upload error: $e',
              style: AppTextStyles.body,
            ),
          ),
        );
      }
    }
  }

  void _startUploadAndNavigate(String filePath) async {
    try {
      final file = File(filePath);
      final fileName = filePath.split('/').last;

      if (!fileName.toLowerCase().endsWith('.mp3') &&
          !fileName.toLowerCase().endsWith('.wav')) {
        debugPrint("Invalid audio file selected");
        _navigateToHomepage();
        return;
      }

      if (!await file.exists()) {
        debugPrint("Selected file does not exist");
        _navigateToHomepage();
        return;
      }

      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        debugPrint("File is too large (>10MB)");
        _navigateToHomepage();
        return;
      }

      final encodedFileName = Uri.encodeComponent(fileName);
      final uri = 'http://192.168.2.1/upload/$encodedFileName';
      debugPrint("Uploading file: $fileName ($fileSize bytes) to $uri");

      var request = http.MultipartRequest('POST', Uri.parse(uri))
        ..headers['Connection'] = 'keep-alive'
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      request.send().then((streamedResponse) async {
        final response = await http.Response.fromStream(streamedResponse);
        debugPrint("Upload response: ${response.statusCode}, ${response.body}");

        if (response.statusCode == 200) {
          debugPrint("✅ Successfully uploaded $fileName");
          final directory = await getApplicationDocumentsDirectory();
          final newPath = '${directory.path}/$fileName';
          await file.copy(newPath);
        } else {
          debugPrint("❌ Upload failed: ${response.statusCode}");
        }
      }).catchError((e) {
        debugPrint("Upload error: $e");
      });

      _navigateToHomepage();

    } catch (e) {
      debugPrint("Upload setup error: $e");
      _navigateToHomepage();
    }
  }

  void _navigateToHomepage() {
    if (mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Recording',
          style: AppTextStyles.heading,
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isConverting)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    'Converting to MP3...',
                    style: AppTextStyles.body,
                  ),
                ],
              )
            else
              Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                size: 80,
                color: _isRecording
                    ? themeProvider.selectedColor
                    : Colors.grey[400],
              ),
            const SizedBox(height: 20),
            Text(
              _isRecording
                  ? 'Recording...'
                  : _mp3FilePath != null
                  ? 'Recording Ready: ${_mp3FilePath!.split('/').last}'
                  : 'Ready to record',
              style: AppTextStyles.heading.copyWith(
                fontSize: 20,
                color: _isRecording
                    ? themeProvider.selectedColor
                    : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            
            // ⏱️ Live Timer Display
            if (_isRecording)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _formatDuration(_currentDuration),
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.selectedColor,
                  ),
                ),
              ),
              
            const SizedBox(height: 20),
            Text(
              _connectionStatus,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _errorMessage!,
                  style: AppTextStyles.body.copyWith(color: Colors.red),
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
                    backgroundColor: _isRecording
                        ? Colors.red
                        : themeProvider.selectedColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _isConverting
                      ? null
                      : _isRecording
                      ? () => _stopRecording(isTimeLimit: false)
                      : _startRecording,
                  child: Text(
                    _isRecording ? 'Stop Recording' : 'Start Recording',
                    style: AppTextStyles.button,
                  ),
                ),
                if (_mp3FilePath != null &&
                    !_isRecording &&
                    !_isConverting) ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 15),
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
                      backgroundColor:
                      _isLooping ? Colors.purple : Colors.grey,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 15),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _saveAndUpload,
                    child: Text(
                      'Save & Upload',
                      style: AppTextStyles.button,
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