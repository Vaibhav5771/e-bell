import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:e_bell/services/bell_service.dart';
import 'dart:typed_data';

class RecordMusicPage extends StatefulWidget {
  const RecordMusicPage({super.key});

  @override
  _RecordMusicPageState createState() => _RecordMusicPageState();
}

class _RecordMusicPageState extends State<RecordMusicPage> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isRecording = false;
  bool _hasRecording = false;
  String? _filePath;
  Timer? wifiCheckTimer;
  String _timerText = '00:00:00';
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isMp3Supported = false;
  bool _isWavSupported = false;
  StreamSubscription? _playerSubscription;
  bool isWifiConnected = false;
  String connectionStatus = 'Checking Wi-Fi...';
  final String targetSsid = 'IoGen_Speaker';

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _initPlayer();
    _checkCodecSupport();
    _startWifiMonitoring();
  }

  Future<void> _startWifiMonitoring() async {
    await _checkWifiConnection();
    wifiCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkWifiConnection();
    });
  }

  Future<void> _initRecorder() async {
    try {
      await _recorder.openRecorder();
      debugPrint("Recorder initialized successfully");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize recorder: $e')),
      );
      debugPrint("Failed to initialize recorder: $e");
    }
  }

  Future<void> _initPlayer() async {
    try {
      await _player.openPlayer();
      debugPrint("Player initialized successfully");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize player: $e')),
      );
      debugPrint("Failed to initialize player: $e");
    }
  }

  Future<void> _checkCodecSupport() async {
    try {
      bool isMp3Supported = await _recorder.isEncoderSupported(Codec.mp3);
      bool isWavSupported = await _recorder.isEncoderSupported(Codec.pcm16WAV);
      if (!mounted) return;
      setState(() {
        _isMp3Supported = isMp3Supported;
        _isWavSupported = isWavSupported;
      });
      debugPrint("MP3 supported: $isMp3Supported, WAV supported: $isWavSupported");
      if (!isMp3Supported && !isWavSupported) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Neither MP3 nor WAV is supported')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to check codec support: $e')),
      );
      debugPrint("Failed to check codec support: $e");
      setState(() {
        _isMp3Supported = false;
        _isWavSupported = false;
      });
    }
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    _recorder.closeRecorder();
    _player.closePlayer();
    wifiCheckTimer?.cancel();
    super.dispose();
  }

  Future<String> _getNextFileName() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = await directory.list().toList();
    int maxNumber = 0;
    for (var file in files) {
      final name = file.path.split('/').last;
      if (name.startsWith('recording_') && name.endsWith('.wav')) {
        final numberStr = name.replaceFirst('recording_', '').replaceFirst('.wav', '');
        final number = int.tryParse(numberStr) ?? 0;
        if (number > maxNumber) maxNumber = number;
      }
    }
    return '${directory.path}/recording_${maxNumber + 1}.wav';
  }

  Future<void> _fixWavHeader(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    if (bytes.length < 44) {
      throw Exception("File too small to be a valid WAV: ${bytes.length} bytes");
    }

    // Update RIFF chunk size (offset 4, size of file - 8)
    final riffSize = bytes.length - 8;
    final riffSizeBytes = ByteData(4)..setInt32(0, riffSize, Endian.little);
    for (int i = 0; i < 4; i++) {
      bytes[4 + i] = riffSizeBytes.getUint8(i);
    }

    // Update data chunk size (offset 40, size of data after header)
    final dataSize = bytes.length - 44;
    final dataSizeBytes = ByteData(4)..setInt32(0, dataSize, Endian.little);
    for (int i = 0; i < 4; i++) {
      bytes[40 + i] = dataSizeBytes.getUint8(i);
    }

    await file.writeAsBytes(bytes, flush: true);
    debugPrint("Fixed WAV header for $filePath: RIFF size=$riffSize, data size=$dataSize");
  }

  Future<void> _startRecording() async {
    if (!isWifiConnected || connectionStatus != "Connected to $targetSsid") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect to IoGen_Speaker Wi-Fi first')),
      );
      debugPrint("Recording blocked: Not connected to $targetSsid");
      return;
    }

    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
        debugPrint("Microphone permission denied");
        return;
      }

      if (!_isWavSupported) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WAV recording not supported')),
        );
        debugPrint("WAV recording not supported");
        return;
      }

      final directory = await getTemporaryDirectory();
      _filePath = '${directory.path}/temp_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.startRecorder(
        toFile: _filePath,
        codec: Codec.pcm16WAV,
        sampleRate: 44100,
        numChannels: 1,
      );

      setState(() {
        _isRecording = true;
        _hasRecording = false;
        _duration = Duration.zero;
        _timerText = '00:00:00';
      });
      debugPrint("Started recording: $_filePath");
      _updateTimer();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording failed: $e')),
      );
      debugPrint("Recording failed: $e");
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopRecording() async {
    try {
      String? stoppedPath = await _recorder.stopRecorder();
      if (stoppedPath == null || stoppedPath != _filePath) {
        debugPrint("Recorder returned unexpected path: $stoppedPath, expected: $_filePath");
      }

      final file = File(_filePath!);
      if (await file.exists()) {
        final length = await file.length();
        debugPrint("Recorded file size: $length bytes");
        if (length < 44) {
          throw Exception("Recorded file is too small, likely corrupted (size: $length bytes)");
        }
      } else {
        throw Exception("Recorded file not found: $_filePath");
      }

      // Fix WAV header
      await _fixWavHeader(_filePath!);

      // Test playability
      try {
        await _player.startPlayer(fromURI: _filePath);
        await Future.delayed(const Duration(seconds: 1));
        await _player.stopPlayer();
        debugPrint("Temporary file is playable");
      } catch (e) {
        throw Exception("Temporary file not playable: $e");
      }

      setState(() {
        _isRecording = false;
        _hasRecording = true;
      });
      debugPrint("Stopped recording: $_filePath");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop recording: $e')),
      );
      debugPrint("Failed to stop recording: $e");
      setState(() {
        _isRecording = false;
        _hasRecording = false;
      });
    }
  }

  void _updateTimer() {
    if (_isRecording) {
      Future.delayed(const Duration(seconds: 1), () {
        if (_isRecording && mounted) {
          setState(() {
            _duration += const Duration(seconds: 1);
            _timerText = _formatDuration(_duration);
          });
          _updateTimer();
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Future<void> _playRecording() async {
    if (_filePath != null && !_isPlaying) {
      try {
        await _player.startPlayer(fromURI: _filePath);
        setState(() {
          _isPlaying = true;
        });
        debugPrint("Started playing: $_filePath");
        _playerSubscription = _player.onProgress!.listen((e) {
          if (e.position >= e.duration!) {
            setState(() {
              _isPlaying = false;
            });
            debugPrint("Playback finished: $_filePath");
          }
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback failed: $e')),
        );
        debugPrint("Playback failed: $e");
      }
    }
  }

  Future<void> _stopPlaying() async {
    if (_isPlaying) {
      try {
        await _player.stopPlayer();
        await _playerSubscription?.cancel();
        setState(() {
          _isPlaying = false;
        });
        debugPrint("Stopped playing: $_filePath");
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop playback: $e')),
        );
        debugPrint("Failed to stop playback: $e");
      }
    }
  }

  Future<bool> _checkWifiConnection() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (!connectivityResult.contains(ConnectivityResult.wifi)) {
        setState(() {
          isWifiConnected = false;
          connectionStatus = "Not connected to Wi-Fi";
        });
        debugPrint("Not connected to Wi-Fi");
        return false;
      }

      final locationStatus = await Permission.locationWhenInUse.request();
      if (!locationStatus.isGranted) {
        setState(() {
          isWifiConnected = false;
          connectionStatus = "Location permission denied";
        });
        debugPrint("Location permission denied");
        return false;
      }

      final networkInfo = NetworkInfo();
      String? wifiSSID;
      try {
        wifiSSID = await networkInfo.getWifiName();
        wifiSSID = wifiSSID?.replaceAll('"', '');
      } on PlatformException catch (e) {
        setState(() {
          isWifiConnected = false;
          connectionStatus = "Error getting Wi-Fi SSID: $e";
        });
        debugPrint("Failed to get Wi-Fi SSID: $e");
        return false;
      }

      debugPrint("Raw Wi-Fi SSID: $wifiSSID");
      setState(() {
        isWifiConnected = wifiSSID != null && wifiSSID.toLowerCase() == targetSsid.toLowerCase();
        connectionStatus = isWifiConnected
            ? "Connected to $targetSsid"
            : "Connected to Wi-Fi: ${wifiSSID ?? 'Unknown'}";
      });
      debugPrint("Connection Status: $connectionStatus");
      return isWifiConnected;
    } catch (e) {
      setState(() {
        isWifiConnected = false;
        connectionStatus = "Error checking Wi-Fi: $e";
      });
      debugPrint("Error checking Wi-Fi: $e");
      return false;
    }
  }

  Future<void> _saveRecording() async {
    if (!_hasRecording || _filePath == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recording available to save')),
      );
      debugPrint("No recording available to save");
      return;
    }

    try {
      final tempFile = File(_filePath!);
      if (!await tempFile.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Temporary file does not exist')),
        );
        debugPrint("Temporary file does not exist: $_filePath");
        return;
      }

      // Get sequential file name
      final newPath = await _getNextFileName();
      final recordedFile = await tempFile.copy(newPath);
      debugPrint("Recording copied to: $newPath");

      // Fix WAV header again after copying
      await _fixWavHeader(newPath);

      // Verify file size
      final fileSize = await recordedFile.length();
      debugPrint("Copied file size: $fileSize bytes");
      if (fileSize < 44) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording is too small, likely corrupted')),
        );
        debugPrint("Copied file is too small: $fileSize bytes");
        return;
      }

      // Test playability
      try {
        await _player.startPlayer(fromURI: newPath);
        await Future.delayed(const Duration(seconds: 1));
        await _player.stopPlayer();
        debugPrint("Copied file is playable");
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording is invalid or corrupted: $e')),
        );
        debugPrint("Copied file not playable: $e");
        return;
      }

      // Check Wi-Fi before upload
      bool isWifiConnected = await _checkWifiConnection();
      if (!isWifiConnected || connectionStatus != "Connected to $targetSsid") {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please connect to IoGen_Speaker Wi-Fi to upload')),
        );
        debugPrint("Upload blocked: Not connected to $targetSsid");
        Navigator.pop(context, newPath);
        return;
      }

      // Upload using BellService
      final bellService = BellService();
      final uploadedFilePath = await bellService.uploadMp3(context, newPath, isWifiConnected);
      if (uploadedFilePath == null) {
        debugPrint('Upload failed, but recording saved locally');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording saved locally but failed to upload')),
        );
      } else {
        debugPrint("Upload successful: $uploadedFilePath");
      }

      if (!mounted) return;
      Navigator.pop(context, newPath);
    } catch (e) {
      if (!mounted) return;
      debugPrint("Error saving/uploading recording: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save/upload recording: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Record Music',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: Color(0xFFF5A623),
              fontSize: 16,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _hasRecording ? _saveRecording : null,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFFF5A623),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                connectionStatus,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF3E0),
              ),
              child: const Icon(
                Icons.mic,
                size: 60,
                color: Color(0xFFF5A623),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              _timerText,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              width: 250,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: CustomPaint(
                painter: WaveformPainter(isRecording: _isRecording),
              ),
            ),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF3E0),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _isRecording ? 'Stop' : 'Start Recording',
                    style: const TextStyle(
                      color: Color(0xFFF5A623),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_hasRecording) ...[
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: _isPlaying ? _stopPlaying : _playRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF3E0),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _isPlaying ? 'Stop Playing' : 'Play Recording',
                      style: const TextStyle(
                        color: Color(0xFFF5A623),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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

class WaveformPainter extends CustomPainter {
  final bool isRecording;

  WaveformPainter({this.isRecording = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 4) {
      double height = isRecording
          ? 30 + (DateTime.now().millisecondsSinceEpoch % 1000) / 50
          : (i < size.width / 3 || i > 2 * size.width / 3)
          ? 30 + (i % 10) * 2
          : 10 + (i % 5) * 2;
      canvas.drawLine(
        Offset(i, size.height / 2 - height / 2),
        Offset(i, size.height / 2 + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => isRecording;
}