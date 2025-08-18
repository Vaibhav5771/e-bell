import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AudioRecorderPage extends StatefulWidget {
  const AudioRecorderPage({super.key});

  @override
  _AudioRecorderPageState createState() => _AudioRecorderPageState();
}

class _AudioRecorderPageState extends State<AudioRecorderPage> {
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  bool _isConverting = false;
  String? _filePath;
  String? _errorMessage;
  bool _permissionsGranted = false;
  bool _isCheckingPermissions = false;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _initRecorder();
  }

  @override
  void dispose() {
    _recorder?.stopRecorder();
    _recorder?.closeRecorder();
    _recorder = null;
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

  Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    return deviceInfo.version.sdkInt >= 33;
  }

  Future<bool> _requestPermissions() async {
    if (_isCheckingPermissions) return false;

    setState(() {
      _isCheckingPermissions = true;
      _errorMessage = null;
    });

    try {
      final isAndroid13Plus = await _isAndroid13OrHigher();
      final permissions = isAndroid13Plus
          ? [Permission.microphone, Permission.audio]
          : [Permission.microphone, Permission.storage];

      final statuses = await permissions.request();

      final allGranted = statuses.values.every((s) => s.isGranted);
      final permanentlyDenied = statuses.values.any((s) => s.isPermanentlyDenied);

      setState(() {
        _permissionsGranted = allGranted;
        if (!allGranted) {
          _errorMessage = permanentlyDenied
              ? 'Permissions permanently denied. Please enable them in app settings.'
              : 'Permissions not granted';
        }
      });

      if (permanentlyDenied) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showPermissionSettingsSnackbar();
        });
      }

      return allGranted;
    } catch (e) {
      setState(() {
        _errorMessage = 'Permission request failed: $e';
      });
      return false;
    } finally {
      setState(() {
        _isCheckingPermissions = false;
      });
    }
  }

  void _showPermissionSettingsSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please enable permissions in app settings'),
        action: SnackBarAction(
          label: 'Open Settings',
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    if (!(await _requestPermissions())) return;

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
        // Delete the original AAC file
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
          Navigator.pop(context, mp3FilePath);
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
                  : 'Ready to record',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _isRecording ? Colors.orange : Colors.black,
              ),
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
          ],
        ),
      ),
    );
  }
}