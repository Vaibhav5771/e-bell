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
  final int? days; // Bitmask: 1=Monday, 2=Tuesday, ..., 64=Sunday
  final Color? selectedColor;
  final VoidCallback? onLongPress; // Add long press support

  const ScheduleItem({
    super.key,
    required this.time,
    this.title = '',
    required this.isChecked,
    this.isLast = false,
    this.icon = Icons.alarm,
    this.days,
    this.selectedColor,
    this.onLongPress,
  });

  Widget _buildDaysRow(int days, Color color) {
    const List<String> abbr = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(7, (i) {
        final bool active = (days & (1 << (i + 1))) != 0; // Bit 1 = Monday
        return Padding(
          padding: const EdgeInsets.only(right: 6.0),
          child: Text(
            abbr[i],
            style: AppTextStyles.subheading.copyWith(
              color: active ? color : Colors.grey.withOpacity(0.6),
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
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

    // Dynamic height based on content
    final hasTitle = title.isNotEmpty;
    final hasDays = days != null;
    final double height = hasTitle && hasDays
        ? 100.0
        : (hasTitle || hasDays)
        ? 90.0
        : 80.0;

    return GestureDetector(
      onLongPress: onLongPress, // Trigger dialog on long press
      child: Container(
        color: Colors.transparent, // Important: allows gesture detection
        child: SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline dot + dotted line
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  if (!isLast)
                    Expanded(
                      child: CustomPaint(
                        painter: DottedLinePainter(color: Colors.grey),
                        size: Size(2, double.infinity),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Time, title, days
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        time,
                        style: AppTextStyles.body.copyWith(fontSize: 18),
                      ),
                      if (title.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[600],
                            decoration: isChecked
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Colors.grey,
                            decorationThickness: 2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (days != null) ...[
                        const SizedBox(height: 6),
                        _buildDaysRow(days!, color),
                      ],
                    ],
                  ),
                ),
              ),

              // Checkbox (read-only)
              Center(
                child: Checkbox(
                  value: isChecked,
                  onChanged: null,
                  activeColor: color,
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Improved Dotted Line Painter
class DottedLinePainter extends CustomPainter {
  final Color color;

  const DottedLinePainter({this.color = Colors.grey});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dashHeight = 6;
    const dashSpace = 6;
    double startY = 4;

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}