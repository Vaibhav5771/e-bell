import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';

class AppSettingScreen extends StatelessWidget {
  const AppSettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // Match the theme colors with ThemePage for consistency
    final List<Color> themeColors = [
      Colors.orange,
      Color(0xFF2274C8),
      Colors.green,
      Colors.blue,
      Colors.red,
      Color(0xFFF6B923),
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
        title: const Text(
          'App Setting',
          style: AppTextStyles.heading,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme',
              style: AppTextStyles.link.copyWith(color: Colors.grey),
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
            Text(
              'Appearance',
              style: AppTextStyles.link.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'Light Mode',
              style: AppTextStyles.body,
            ),
            const Divider(height: 32),
            Text(
              'Language',
              style: AppTextStyles.link.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'English (IN)',
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}