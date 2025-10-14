// import 'package:flutter/material.dart';
// import 'package:audioplayers/audioplayers.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import '../utils/app_text_styles.dart';
//
// class ComingSoonPage extends StatefulWidget {
//   const ComingSoonPage({super.key});
//
//   @override
//   State<ComingSoonPage> createState() => _ComingSoonPageState();
// }
//
// class _ComingSoonPageState extends State<ComingSoonPage> {
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   List<String> _soundOptions = [];
//   String? _currentlyPlaying;
//   bool _isLoading = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUploadedFiles();
//   }
//
//   @override
//   void dispose() {
//     _audioPlayer.dispose();
//     super.dispose();
//   }
//
//   Future<void> _loadUploadedFiles() async {
//     setState(() => _isLoading = true);
//     try {
//       final response = await http.get(Uri.parse('http://192.168.2.1/')).timeout(
//         const Duration(seconds: 10),
//         onTimeout: () {
//           throw Exception('Request to IoT device timed out');
//         },
//       );
//
//       if (response.statusCode == 200) {
//         final jsonData = jsonDecode(response.body);
//         final alarmData = jsonData['alarmData'] as List<dynamic>?;
//         if (alarmData != null && alarmData.isNotEmpty) {
//           final filenames = (alarmData[0]['Filenames'] as List<dynamic>?)?.map((
//               file) {
//             return (file as List<dynamic>)[0] as String;
//           }).toList() ?? [];
//           setState(() {
//             _soundOptions = filenames
//                 .where((file) =>
//             !file.contains('/') &&
//                 (file.toLowerCase().endsWith('.mp3') ||
//                     file.toLowerCase().endsWith('.wav')))
//                 .toList();
//           });
//           if (_soundOptions.isEmpty) {
//             _showSnackBar(
//                 'No valid audio files (MP3 or WAV) found in root directory.');
//           }
//         } else {
//           setState(() => _soundOptions = []);
//           _showSnackBar('No sound files found in root directory.');
//         }
//       } else {
//         _showSnackBar(
//             'Failed to fetch sounds from device: ${response.statusCode}');
//       }
//     } catch (e) {
//       _showSnackBar(
//           'Error fetching sounds: Ensure you are connected to the speaker\'s Wi-Fi. Error: $e');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   void _showSnackBar(String message) {
//     // if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             message,
//             style: AppTextStyles.body.copyWith(color: Colors.white),
//           ),
//           backgroundColor: Colors.black87,
//         ),
//       );
//     }
//   }
//
//   Future<void> _playSound(String soundFile) async {
//     if (_currentlyPlaying == soundFile) {
//       await _audioPlayer.stop();
//       setState(() => _currentlyPlaying = null);
//       return;
//     }
//
//     try {
//       final soundUrl = 'http://192.168.2.1/sounds/$soundFile';
//       await _audioPlayer.play(UrlSource(soundUrl));
//       setState(() => _currentlyPlaying = soundFile);
//       _audioPlayer.onPlayerComplete.listen((event) {
//         setState(() => _currentlyPlaying = null);
//       });
//     } catch (e) {
//       _showSnackBar('Error playing sound: $e');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         surfaceTintColor: Colors.white,
//         title: Text('Music Category', style: AppTextStyles.heading),
//         centerTitle: true,
//       ),
//       body: _isLoading
//           ? const Center(
//           child: CircularProgressIndicator(color: Colors.blueAccent))
//           : SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const SizedBox(height: 40),
//               Image.asset('assets/comingsoon.png', height: 200),
//               const SizedBox(height: 24),
//               Text(
//                 'This feature is coming soon!',
//                 style: AppTextStyles.heading.copyWith(
//                     fontWeight: FontWeight.bold, fontSize: 24),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 'We\'re working on something amazing. Stay tuned!',
//                 style: AppTextStyles.body.copyWith(color: Colors.grey[600]),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 40),
//               Card(
//                 elevation: 0,
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12)),
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Available Sounds on Device',
//                         style: AppTextStyles.subheading.copyWith(
//                             fontWeight: FontWeight.bold),
//                       ),
//                       const Divider(height: 20, thickness: 1),
//                       if (_soundOptions.isEmpty)
//                         Padding(
//                           padding: const EdgeInsets.symmetric(vertical: 20.0),
//                           child: Center(
//                             child: Text(
//                               'No audio files found.',
//                               style: AppTextStyles.link.copyWith(
//                                   color: Colors.grey),
//                             ),
//                           ),
//                         )
//                       else
//                         GridView.builder(
//                           shrinkWrap: true,
//                           physics: const NeverScrollableScrollPhysics(),
//                           itemCount: _soundOptions.length,
//                           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                             crossAxisCount: 2,
//                             // You can change this to 3 for a denser grid
//                             crossAxisSpacing: 10,
//                             mainAxisSpacing: 10,
//                             childAspectRatio: 2.0, // Adjust this ratio for item height
//                           ),
//                           itemBuilder: (context, index) {
//                             final sound = _soundOptions[index];
//                             final isPlaying = _currentlyPlaying == sound;
//                             return InkWell(
//                               onTap: () => _playSound(sound),
//                               child: Card(
//                                 color: isPlaying ? Colors.blueAccent
//                                     .withOpacity(0.1) : Colors.white,
//                                 elevation: 2,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   side: BorderSide(
//                                     color: isPlaying
//                                         ? Colors.blueAccent
//                                         : Colors.grey.shade300,
//                                     width: 1.5,
//                                   ),
//                                 ),
//                                 child: Center(
//                                   child: Padding(
//                                     padding: const EdgeInsets.all(8.0),
//                                     child: Row(
//                                       mainAxisAlignment: MainAxisAlignment
//                                           .center,
//                                       children: [
//                                         Icon(
//                                           isPlaying ? Icons.stop : Icons
//                                               .play_arrow,
//                                           color: isPlaying
//                                               ? Colors.redAccent
//                                               : Colors.blueAccent,
//                                         ),
//                                         const SizedBox(width: 8),
//                                         Expanded(
//                                           child: Text(
//                                             sound
//                                                 .split('.')
//                                                 .first,
//                                             style: AppTextStyles.body.copyWith(
//                                               fontWeight: FontWeight.bold,
//                                               color: isPlaying ? Colors
//                                                   .blueAccent : Colors.black87,
//                                             ),
//                                             overflow: TextOverflow.ellipsis,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                     ],
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 20),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }