import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class AudioRecorderPage extends StatefulWidget {
  const AudioRecorderPage({super.key});

  @override
  State<AudioRecorderPage> createState() => _AudioRecorderPageState();
}

class _AudioRecorderPageState extends State<AudioRecorderPage> {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  String? _filePath;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    await _recorder!.openRecorder();
    await _player!.openPlayer();
    await Permission.microphone.request();
    await Permission.storage.request(); // For file access
  }

  Future<void> _convertToWav() async {
    if (_filePath == null || !File(_filePath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recording found')),
      );
      return;
    }

    setState(() {
      _isConverting = true;
    });

    try {
      final uri = Uri.parse('https://e-bell.onrender.com/convert');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('audio', _filePath!));

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        final bytes = await streamedResponse.stream.toBytes();
        final dir = await getApplicationDocumentsDirectory();
        final outputPath = '${dir.path}/converted.wav';
        final file = File(outputPath);
        await file.writeAsBytes(bytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WAV saved at: $outputPath')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversion failed: ${streamedResponse.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isConverting = false;
      });
    }
  }

  Future<String> _getFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return "${dir.path}/recorded.aac";
  }

  Future<void> _startRecording() async {
    if (await Permission.microphone.isDenied) {
      throw Exception('Microphone permission not granted');
    }

    _filePath = await _getFilePath();
    await _recorder!.startRecorder(
      toFile: _filePath,
      codec: Codec.aacADTS,
    );

    setState(() {});
  }

  Future<void> _stopRecording() async {
    await _recorder!.stopRecorder();
    setState(() {});
  }

  Future<void> _playRecording() async {
    if (_filePath == null || !File(_filePath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recording found')),
      );
      return;
    }
    await _player!.startPlayer(fromURI: _filePath);
  }

  @override
  void dispose() {
    _recorder!.closeRecorder();
    _player!.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Recorder (AAC)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _recorder!.isRecording
                  ? _stopRecording
                  : _startRecording,
              child: Text(_recorder!.isRecording
                  ? 'Stop Recording'
                  : 'Start Recording'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _playRecording,
              child: const Text('Play Recording'),
            ),
            const SizedBox(height: 20),
            Text(_filePath ?? 'No file recorded yet.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isConverting ? null : _convertToWav,
              child: _isConverting
                  ? const CircularProgressIndicator()
                  : const Text('Convert to WAV'),
            ),
          ],
        ),
      ),
    );
  }
}