import 'package:flutter/material.dart';

class AddmusicPage extends StatelessWidget {
  const AddmusicPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Navigate back to the previous page
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFFF5A623), // Orange color from the image
                  fontSize: 16,
                ),
              ),
            ),
            const Text(
              'Add Music',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // TODO: Implement save functionality
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Color(0xFFF5A623), // Orange color for Save button
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        centerTitle: false, // Disable default centering
        automaticallyImplyLeading: false, // Remove default leading space
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder_open,
              size: 60,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            const Text(
              'Tap to browse files',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for a simple waveform representation
class WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;

    // Draw a simple waveform pattern
    for (double i = 0; i < size.width; i += 4) {
      double height = (i < size.width / 3 || i > 2 * size.width / 3)
          ? 30 + (i % 10) * 2
          : 10 + (i % 5) * 2;
      canvas.drawLine(
        Offset(i, size.height / 2 - height / 2),
        Offset(i, size.height / 2 + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}