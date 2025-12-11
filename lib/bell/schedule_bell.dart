import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../utils/theme_state.dart'; // Assuming this file exists

// --- Top-Level Class for JSON Decoding ---
/// API response structure for decoding the song list.
class BellFileResponse {
  // Use a generic list to safely extract the nested "Data" array.
  final List<dynamic> data; 
  
  BellFileResponse({required this.data});

  factory BellFileResponse.fromJson(Map<String, dynamic> json) {
    // Safely extract the data list, defaulting to empty list if key is missing or not a List.
    final List<dynamic> dataList = json['Data'] as List<dynamic>? ?? [];

    return BellFileResponse(data: dataList);
  }
}

// ---------------------------------------------------------------------------------

class BellSoundChanger extends StatefulWidget {
  const BellSoundChanger({super.key});

  @override
  _BellSoundChangerState createState() => _BellSoundChangerState();
}

class _BellSoundChangerState extends State<BellSoundChanger> {
  // Stores all file names from the API.
  List<String> allBellFiles = [];
  // Stores the currently selected file name (set initially by API or user).
  String? selectedBellFile;
  bool isLoading = true; 
  final String baseUrl = 'http://192.168.2.1'; // Base URL for the speaker API

  @override
  void initState() {
    super.initState();
    fetchBellFilesAndCurrentSelection();
  }

  /// Fetches the list of all songs and identifies the currently selected one (marked with 1).
  Future<void> fetchBellFilesAndCurrentSelection() async {
    setState(() => isLoading = true);
    final String url = '$baseUrl/songs';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        
        final bellResponse = BellFileResponse.fromJson(jsonResponse);
        
        final List<String> allFiles = [];
        String? currentFile;

        // Traverse the outer 'Data' list (bellResponse.data)
        if (bellResponse.data.isNotEmpty && bellResponse.data[0] is Map) {
          final filesMap = bellResponse.data[0] as Map<String, dynamic>;
          
          // Access the inner 'files' list
          final filesList = filesMap['files'] as List<dynamic>? ?? [];

          for (var fileEntry in filesList) {
            // fileEntry is expected to be a List like ["filename.mp3", 0/1]
            if (fileEntry is List && fileEntry.length == 2) {
              final fileName = fileEntry[0].toString(); // Ensure file name is a String
              final selectionFlag = fileEntry[1];

              allFiles.add(fileName);

              // CRITICAL PARSING: Check if the flag value is 1 (integer or string)
              bool isSelected = false;
              if (selectionFlag is int) {
                isSelected = selectionFlag == 1;
              } else if (selectionFlag is String) {
                isSelected = selectionFlag == '1'; 
              }
              
              if (isSelected) {
                // This correctly captures the file name marked with '1'
                currentFile = fileName; 
              }
            }
          }
        }
        
        setState(() {
          allBellFiles = allFiles;
          // Set the selected file to the one marked '1'.
          // Fallback: If currentFile is null, use the first available file.
          selectedBellFile = currentFile ?? (allFiles.isNotEmpty ? allFiles.first : null);
        });
      } else {
        _showDialog("Error Fetching Data", "Failed to load files with status: ${response.statusCode}");
      }
    } catch (e) {
      _showDialog("Connection Error", "Could not connect to speaker API or parsing error.\nError: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Sends the request to change the bell sound.
  Future<void> sendBellChangeRequest() async {
    if (selectedBellFile == null) {
      _showDialog("Error", "No bell sound selected.");
      return;
    }
    
    String url = '$baseUrl/intrsong/$selectedBellFile';

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

  /// Utility method to show an alert dialog.
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
    
    // Show a loading screen while initial data is being fetched
    if (isLoading && selectedBellFile == null && allBellFiles.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bell Configuration')),
        body: Center(
          child: CircularProgressIndicator(color: themeProvider.selectedColor),
        ),
      );
    }
    
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
            onPressed: (isLoading || selectedBellFile == null) ? null : sendBellChangeRequest,
            child: Text(
              'Save',
              style: TextStyle(
                color: (isLoading || selectedBellFile == null) ? Colors.grey : themeProvider.selectedColor,
                fontSize: 16,
              ),
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
                // DropdownButton must be built only when data is ready
                if (allBellFiles.isNotEmpty && selectedBellFile != null)
                  DropdownButton<String>(
                    // This 'value' property correctly displays the selected item from the API.
                    value: selectedBellFile, 
                    items: allBellFiles.map((file) {
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
                    // Removed selectedItemBuilder to rely on default, correct display logic
                  ),
                if (allBellFiles.isEmpty)
                  const Text('No files found.', style: TextStyle(color: Colors.red)),
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
                      onPressed: selectedBellFile == null ? null : sendBellChangeRequest,
                      icon: Icon(
                        Icons.music_note,
                        color: selectedBellFile == null ? Colors.grey : themeProvider.selectedColor,
                      ),
                      label: Text(
                        'Send to Bell',
                        style: TextStyle(
                          color: selectedBellFile == null ? Colors.grey : themeProvider.selectedColor,
                          fontSize: 14,
                        ),
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