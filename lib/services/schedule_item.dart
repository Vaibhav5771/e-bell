import 'package:flutter/material.dart';

class ScheduleItem extends StatelessWidget {
  final String time;
  final String title;
  final bool isChecked;
  final bool isLast; // Add to hide the dotted line for the last item

  const ScheduleItem({
    super.key,
    required this.time,
    required this.title,
    required this.isChecked,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100, // Adjust height as needed
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.alarm,
                  color: Colors.orange,
                  size: 30,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: CustomPaint(
                    painter: DottedLinePainter(),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 45),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.grey,
                      decorationThickness: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Checkbox(
            value: isChecked,
            onChanged: null,
            activeColor: Colors.orange,
          ),
        ],
      ),
    );
  }
}

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1;

    const dashHeight = 4;
    const dashSpace = 4;
    double startY = 0;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
