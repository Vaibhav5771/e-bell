import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/theme_state.dart';

class BellSoundChanger extends StatefulWidget {
  const BellSoundChanger({super.key});

  @override
  _BellSoundChangerState createState() => _BellSoundChangerState();
}

class _BellSoundChangerState extends State<BellSoundChanger> {
  final List<String> bellFiles = ['ANUV.MP3', 'FLUTE.MP3', 'JINGLE.MP3'];
  String selectedBellFile = 'ANUV.MP3';
  bool isLoading = false;

  Future<void> sendBellChangeRequest() async {
    String url = 'http://192.168.2.1/intrsong/$selectedBellFile';

    setState(() => isLoading = true);

    try {
      final response = await http.post(Uri.parse(url));
      if (response.statusCode == 200) {
        _showDialog("Success", "Bell sound changed to $selectedBellFile");
      } else {
        _showDialog("Error", "Failed with status: ${response.statusCode}");
      }
    } catch (e) {
      _showDialog("Connection Error", "Make sure you're connected to the speaker's Wi-Fi.\n\nError: $e");
    }

    setState(() => isLoading = false);
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 5.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: Text(
                'Cancel',
                style: TextStyle(color: themeProvider.selectedColor, fontSize: 16),
              ),
            ),
          ),
        ),
        title: const Text(
          'Bell Configuration',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () {
              sendBellChangeRequest();
            },
            child: Text(
              'Save',
              style: TextStyle(color: themeProvider.selectedColor, fontSize: 16),
            ),
          ),
        ],
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sound',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                ),
                DropdownButton<String>(
                  value: selectedBellFile,
                  items: bellFiles.map((file) {
                    return DropdownMenuItem<String>(
                      value: file,
                      child: Text(
                        file,
                        style: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => selectedBellFile = value!),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.chevron_right, color: Colors.grey),
                  isDense: true,
                  alignment: Alignment.centerRight,
                  style: const TextStyle(fontWeight: FontWeight.w400, color: Colors.black),
                  selectedItemBuilder: (BuildContext context) {
                    return bellFiles.map((file) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          file,
                          style: const TextStyle(fontWeight: FontWeight.w400),
                        ),
                      );
                    }).toList();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              color: Colors.grey[300],
              thickness: 0.5,
              height: 0,
            ),
            const SizedBox(height: 16),
            Center(
              child: isLoading
                  ? CircularProgressIndicator(color: themeProvider.selectedColor)
                  : ElevatedButton.icon(
                onPressed: sendBellChangeRequest,
                icon: Icon(Icons.music_note, color: themeProvider.selectedColor),
                label: Text(
                  'Send to Bell',
                  style: TextStyle(color: themeProvider.selectedColor, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}