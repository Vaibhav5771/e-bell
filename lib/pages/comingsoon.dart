import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import '../utils/app_text_styles.dart';

class ComingSoonPage extends StatefulWidget {
  const ComingSoonPage({super.key});

  @override
  State<ComingSoonPage> createState() => _ComingSoonPageState();
}

class _ComingSoonPageState extends State<ComingSoonPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _playerCompleteSub;

  static const String _baseUrl = 'http://192.168.2.1';
  List<String> _soundOptions = [];
  String? _currentlyPlaying;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUploadedFiles();
    // subscribe once
    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _currentlyPlaying = null);
    });
  }

  @override
  void dispose() {
    _playerCompleteSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadUploadedFiles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse('$_baseUrl/');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException('Request timed out'),
      );

      if (response.statusCode != 200) {
        _showSnackBar('Failed to fetch sounds: ${response.statusCode}');
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        _showSnackBar('Unexpected response format from device.');
        return;
      }

      final alarmData = decoded['alarmData'];
      if (alarmData is! List || alarmData.isEmpty) {
        _showSnackBar('No sound files found in root directory.');
        setState(() => _soundOptions = []);
        return;
      }

      final first = alarmData[0];
      final filenamesRaw = (first is Map && first['Filenames'] is List)
          ? first['Filenames'] as List
          : null;

      final filenames = <String>[];
      if (filenamesRaw != null) {
        for (final item in filenamesRaw) {
          // your old data shape implied each item is a List and filename is at index 0
          if (item is List && item.isNotEmpty && item[0] is String) {
            filenames.add(item[0] as String);
          } else if (item is String) {
            filenames.add(item);
          }
        }
      }

      final filtered = filenames
          .where((file) =>
      !file.contains('/') &&
          (file.toLowerCase().endsWith('.mp3') ||
              file.toLowerCase().endsWith('.wav')))
          .toList();

      if (!mounted) return;
      setState(() => _soundOptions = filtered);

      if (filtered.isEmpty) {
        _showSnackBar('No valid audio files (MP3/WAV) found in root directory.');
      }
    } on TimeoutException catch (e) {
      _showSnackBar('Timeout: ensure you are connected to the speaker Wi-Fi. $e');
    } catch (e) {
      _showSnackBar('Error fetching sounds: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTextStyles.body.copyWith(color: Colors.white)),
        backgroundColor: Colors.black87,
      ),
    );
  }

  Future<void> _playSound(String soundFile) async {
    if (_currentlyPlaying == soundFile) {
      try {
        await _audioPlayer.stop();
      } catch (_) {}
      if (!mounted) return;
      setState(() => _currentlyPlaying = null);
      return;
    }

    try {
      // Stop current playback
      await _audioPlayer.stop();

      final encoded = Uri.encodeComponent(soundFile);
      final soundUrl = '$_baseUrl/sounds/$encoded';

      // Start playing
      await _audioPlayer.play(UrlSource(soundUrl));

      if (!mounted) return;
      setState(() => _currentlyPlaying = soundFile);
    } catch (e) {
      _showSnackBar('Error playing sound: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text('Music Category', style: AppTextStyles.heading),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : RefreshIndicator(
        onRefresh: _loadUploadedFiles,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Image.asset('assets/comingsoon.png', height: 200),
                const SizedBox(height: 24),
                Text(
                  'This feature is coming soon!',
                  style: AppTextStyles.heading.copyWith(fontWeight: FontWeight.bold, fontSize: 24),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'We\'re working on something amazing. Stay tuned!',
                  style: AppTextStyles.body.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Sounds on Device',
                          style: AppTextStyles.subheading.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Divider(height: 20, thickness: 1),
                        if (_soundOptions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Center(
                              child: Text(
                                'No audio files found.',
                                style: AppTextStyles.link.copyWith(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _soundOptions.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 2.0,
                            ),
                            itemBuilder: (context, index) {
                              final sound = _soundOptions[index];
                              final isPlaying = _currentlyPlaying == sound;
                              return InkWell(
                                onTap: () => _playSound(sound),
                                child: Card(
                                  color: isPlaying ? Colors.blueAccent.withOpacity(0.1) : Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isPlaying ? Colors.blueAccent : Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(isPlaying ? Icons.stop : Icons.play_arrow,
                                              color: isPlaying ? Colors.redAccent : Colors.blueAccent),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              sound.split('.').first,
                                              style: AppTextStyles.body.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: isPlaying ? Colors.blueAccent : Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
