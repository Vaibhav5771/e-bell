import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ComingSoonPage extends StatefulWidget {
  const ComingSoonPage({super.key});

  @override
  State<ComingSoonPage> createState() => _ComingSoonPageState();
}

class _ComingSoonPageState extends State<ComingSoonPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> _soundOptions = [];
  String? _currentlyPlaying;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUploadedFiles();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadUploadedFiles() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('http://192.168.2.1/')).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request to IoT device timed out');
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final alarmData = jsonData['alarmData'] as List<dynamic>?;
        if (alarmData != null && alarmData.isNotEmpty) {
          final filenames = (alarmData[0]['Filenames'] as List<dynamic>?)?.map((file) {
            return (file as List<dynamic>)[0] as String;
          }).toList() ?? [];
          setState(() {
            _soundOptions = filenames
                .where((file) =>
            !file.contains('/') &&
                (file.toLowerCase().endsWith('.mp3') || file.toLowerCase().endsWith('.wav')))
                .toList();
          });
          if (_soundOptions.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No valid audio files (MP3 or WAV) found in root directory.')),
            );
          }
        } else {
          setState(() => _soundOptions = []);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No sound files found in root directory.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch sounds from device: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching sounds: Ensure you are connected to the speaker\'s Wi-Fi. Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _playSound(String soundFile) async {
    if (_currentlyPlaying == soundFile) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlaying = null);
      return;
    }

    try {
      // Assuming sounds are accessible via HTTP from the device
      final soundUrl = 'http://192.168.2.1/sounds/$soundFile'; // Adjust the path as per your device's API
      await _audioPlayer.play(UrlSource(soundUrl));
      setState(() => _currentlyPlaying = soundFile);
      _audioPlayer.onPlayerComplete.listen((event) {
        setState(() => _currentlyPlaying = null);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing sound: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text('Music Category'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/comingsoon.png'),
              const SizedBox(height: 20),
              const Text(
                'This feature is coming soon!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Stay tuned!!!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Available Sounds on Device',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (_soundOptions.isEmpty)
                const Text(
                  'No audio files found.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _soundOptions.length,
                  itemBuilder: (context, index) {
                    final sound = _soundOptions[index];
                    return ListTile(
                      title: Text(sound),
                      trailing: Icon(
                        _currentlyPlaying == sound ? Icons.stop : Icons.play_arrow,
                        color: Colors.blue,
                      ),
                      onTap: () => _playSound(sound),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}