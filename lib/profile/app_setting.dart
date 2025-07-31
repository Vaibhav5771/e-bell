import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/theme_state.dart';


class AppSettingScreen extends StatelessWidget {
  const AppSettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // Match the theme colors with ThemePage for consistency
    final List<Color> themeColors = [
      Colors.orange,
      Colors.lightBlue,
      Colors.green,
      Colors.blue,
      Colors.red,
      Colors.orange[100]!,
      Colors.black87,
      Colors.teal,
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.selectedColor),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('App Setting'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Theme',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: themeColors.map((color) {
                final isSelected = themeProvider.selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    themeProvider.setColor(color);
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 32),
            const Text(
              'Appearance',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Light Mode',
              style: TextStyle(fontSize: 16),
            ),
            const Divider(height: 32),
            const Text(
              'Language',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'English (IN)',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}