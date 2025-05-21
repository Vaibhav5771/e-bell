import 'package:flutter/material.dart';

class ScheduleItem extends StatelessWidget {
  final String time;
  final String title;
  final bool isChecked;

  const ScheduleItem({
    super.key,
    required this.time,
    required this.title,
    required this.isChecked,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.alarm,
          color: Colors.grey,
          size: 24,
        ),
        const SizedBox(width: 16),
        Column(
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
                fontSize: 16,
                fontWeight: FontWeight.w500,
                decoration: isChecked ? TextDecoration.lineThrough : null,
                decorationColor: Colors.grey,
                decorationThickness: 2,
              ),
            ),
          ],
        ),
        const Spacer(),
        Checkbox(
          value: isChecked,
          onChanged: null, // Read-only for now
          activeColor: Colors.orange,
        ),
      ],
    );
  }
}