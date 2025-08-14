import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderPage extends StatefulWidget {
  const AudioRecorderPage({super.key});

  @override
  _AudioRecorderPageState createState() => _AudioRecorderPageState();
}

class _AudioRecorderPageState extends State<AudioRecorderPage> {
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  String? _filePath;

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
    await _recorder?.openRecorder();
  }

  Future<void> _startRecording() async {
    if (await Permission.microphone.request().isGranted) {
      final directory = await getTemporaryDirectory();
      _filePath =
      '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder?.startRecorder(
        toFile: _filePath,
        codec: Codec.aacADTS,
      );
      setState(() {
        _isRecording = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
    }
  }

  Future<void> _stopRecording() async {
    await _recorder?.stopRecorder();
    setState(() {
      _isRecording = false;
    });
    if (_filePath != null) {
      Navigator.pop(context, _filePath);
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
            Icon(
              _isRecording ? Icons.mic : Icons.mic_none,
              size: 80,
              color: _isRecording ? Colors.orange : Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              _isRecording ? 'Recording...' : 'Ready to record',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _isRecording ? Colors.orange : Colors.black,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : Colors.orange,
                padding:
                const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              onPressed:
              _isRecording ? _stopRecording : _startRecording,
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
