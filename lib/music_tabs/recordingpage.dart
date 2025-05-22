import 'package:flutter/material.dart';

class RecordMusicPage extends StatelessWidget {
  const RecordMusicPage({super.key});

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
              'Record Music',
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
            // Microphone icon in a circular container
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF3E0), // Light peach background color
              ),
              child: const Icon(
                Icons.mic,
                size: 60,
                color: Color(0xFFF5A623), // Orange color for the mic icon
              ),
            ),
            const SizedBox(height: 40),
            // Timer text
            const Text(
              '00:00:00',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 30),
            // Waveform placeholder (simplified as a container with a pattern)
            Container(
              width: 250,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: CustomPaint(
                painter: WaveformPainter(),
              ),
            ),
            const SizedBox(height: 60),
            // Start Recording button
            ElevatedButton(
              onPressed: () {
                // TODO: Implement start recording functionality
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF3E0), // Light peach button color
                padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Start Recording',
                style: TextStyle(
                  color: Color(0xFFF5A623), // Orange text color
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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