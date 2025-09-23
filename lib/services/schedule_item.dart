import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';

class ScheduleItem extends StatelessWidget {
  final String time;
  final String title;
  final bool isChecked;
  final bool isLast;
  final IconData? icon;

  const ScheduleItem({
    super.key,
    required this.time,
    required this.title,
    required this.isChecked,
    this.isLast = false,
    this.icon = Icons.alarm,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return SizedBox(
      height: 80, // Reduced height for compact layout
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: themeProvider.selectedColor.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: themeProvider.selectedColor,
                  size: 24,
                ),
              ),
              if (!isLast)
                SizedBox(
                  height: 30, // Fixed height for dotted line
                  child: CustomPaint(
                    painter: DottedLinePainter(),
                    size: const Size(2, 30), // Explicit size for CustomPaint
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time,
                    style: AppTextStyles.subheading,
                  ),
                  Text(
                    title,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.grey,
                      decorationThickness: 2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          Checkbox(
            value: isChecked,
            onChanged: null,
            activeColor: themeProvider.selectedColor,
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
      ..strokeWidth = 2;

    const dashHeight = 3;
    const dashSpace = 5;
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