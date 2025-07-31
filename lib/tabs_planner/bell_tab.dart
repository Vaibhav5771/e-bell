import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/theme_state.dart';

class BellTab extends StatefulWidget {
  const BellTab({super.key});

  @override
  State<BellTab> createState() => _BellTabState();
}

class _BellTabState extends State<BellTab> {
  final List<String> _bellSounds = ['ANUV.MP3', 'FLUTE.MP3', 'JINGLE.MP3'];
  String _selectedSound = 'ANUV.MP3';
  bool _isSending = false;
  bool _isUploading = false;

  Future<void> _setBellSound() async {
    setState(() => _isSending = true);

    try {
      final response = await http.post(
          Uri.parse('http://192.168.2.1/intrsong/$_selectedSound'));

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showDialog('Success', 'Bell sound updated successfully', true);
      } else {
        _showDialog('Error', 'Failed to update bell sound', false);
      }
    } catch (e) {
      if (!mounted) return;
      _showDialog('Connection Error',
          'Please check your Wi-Fi connection\n\nError: ${e.toString()}', false);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _uploadSoundFile() async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (!mounted) return;
        _showDialog(
            'Permission Required', 'Storage permission is needed to select audio files', false);
        return;
      }

      // Pick the audio file
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);

      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploading = true);
      final file = result.files.first;

      // Validate file type (optional client-side check)
      if (!file.name.toLowerCase().endsWith('.mp3') &&
          !file.name.toLowerCase().endsWith('.wav')) {
        if (!mounted) return;
        _showDialog('Invalid File', 'Please select an MP3 or WAV audio file', false);
        setState(() => _isUploading = false);
        return;
      }

      // Create multipart request
      final request = http.MultipartRequest(
          'POST', Uri.parse('http://192.168.2.1/uploadintr/${file.name}'));

      // Add the file to the request
      request.files.add(await http.MultipartFile.fromPath('file', file.path!));

      // Send the request
      final response = await request.send();

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          if (!_bellSounds.contains(file.name)) {
            _bellSounds.add(file.name);
          }
          _selectedSound = file.name;
        });
        await _setBellSound(); // Auto-set the new sound
      } else {
        _showDialog('Error', 'Failed to upload file. Status code: ${response.statusCode}', false);
      }
    } catch (e) {
      if (mounted) {
        _showDialog('Error', 'File upload failed: ${e.toString()}', false);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showDialog(String title, String message, bool isSuccess) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          isSuccess ? Icons.check_circle : Icons.error,
          color: isSuccess ? Colors.green : Colors.red,
          size: 40,
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    print('BellTab: Using color ${themeProvider.selectedColor}');
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Sound Selection Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT BELL SOUND',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Sound Dropdown
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButton<String>(
                              value: _selectedSound,
                              items: _bellSounds
                                  .map((sound) => DropdownMenuItem(
                                value: sound,
                                child: Text(sound),
                              ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedSound = value);
                                  _setBellSound();
                                }
                              },
                              isExpanded: true,
                              underline: const SizedBox(),
                              borderRadius: BorderRadius.circular(8),
                              icon: Icon(Icons.arrow_drop_down, color: themeProvider.textColor),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Upload Button
                      ElevatedButton(
                        onPressed: _isUploading ? null : _uploadSoundFile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: themeProvider.selectedColor,
                          side: BorderSide(color: themeProvider.selectedColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        child: _isUploading
                            ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: themeProvider.selectedColor,
                          ),
                        )
                            : const Text('New'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Apply Button
          ElevatedButton(
            onPressed: _isSending ? null : _setBellSound,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              iconColor: themeProvider.selectedColor,
              backgroundColor: themeProvider.selectedColor,
              foregroundColor: Colors.white,
            ),
            child: _isSending
                ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Applying...'),
              ],
            )
                : const Text('APPLY BELL SOUND'),
          ),
        ],
      ),
    );
  }
}