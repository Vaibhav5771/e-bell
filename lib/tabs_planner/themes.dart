import 'package:e_bell/pages/home_page.dart';
import 'package:flutter/material.dart';


// Global variable to store the selected theme color (you can replace this with SharedPreferences or state management later)
Color? selectedThemeColor;

class ThemePage extends StatefulWidget {
  const ThemePage({super.key});

  @override
  State<ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends State<ThemePage> {
  // List of available theme colors (matching the image)
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

  // Navigate to HomePage
  void _navigateToHomePage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top row with "Skip" button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _navigateToHomePage,
                    child: const Text(
                      'Skip',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // "Select theme" title
            const Text(
              'Select theme',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            // Grid of colored circles
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: themeColors.length,
                itemBuilder: (context, index) {
                  final color = themeColors[index];
                  final isSelected = selectedThemeColor == color;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedThemeColor = color;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            const Spacer(),
            // "Get Started" button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
              child: ElevatedButton(
                onPressed: _navigateToHomePage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}