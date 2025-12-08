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
  final int? days;
  final Color? selectedColor;

  const ScheduleItem({
    super.key,
    required this.time,
    required this.title,
    required this.isChecked,
    this.isLast = false,
    this.icon = Icons.alarm,
    this.days,
    this.selectedColor,
  });

  Widget _buildDaysRow(int days, Color color) {
    final List<String> abbr = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final List<int> bits = [1, 2, 3, 4, 5, 6, 7];
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(7, (i) {
        final bool active = (days & (1 << bits[i])) != 0;
        return Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: Text(
            abbr[i],
            style: AppTextStyles.subheading.copyWith(
              color: active ? color : Colors.grey,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final color = selectedColor ?? themeProvider.selectedColor;

    // Calculate height based on content
    final hasTitle = title.isNotEmpty;
    final hasDays = days != null;
    final height = (hasTitle && hasDays) ? 100 :
    (hasTitle || hasDays) ? 90 : 80;

    return SizedBox(
      height: height.toDouble(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              if (!isLast)
                SizedBox(
                  height: (height - 44).toDouble(), // Adjust dotted line height dynamically
                  child: CustomPaint(
                    painter: DottedLinePainter(),
                    size: Size(2, (height - 44).toDouble()),
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
                    style: AppTextStyles.body,
                  ),
                  if (title.isNotEmpty) // Only show title if not empty
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
                  if (days != null) // Only show days if provided
                    Padding(
                      padding: EdgeInsets.only(top: title.isNotEmpty ? 4 : 2),
                      child: _buildDaysRow(days!, color),
                    ),
                ],
              ),
            ),
          ),
          Checkbox(
            value: isChecked,
            onChanged: null,
            activeColor: color,
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