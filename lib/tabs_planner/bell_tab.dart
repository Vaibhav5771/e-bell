import 'package:flutter/material.dart';

class BellTab extends StatelessWidget {
  const BellTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: ListView(
        children: const [
          BellCard(
            title: 'Working hrs',
            sound: 'Opening(default)',
            schedule: '9am to 6pm',
            repeat: 'M T W T F S S',
          ),
          SizedBox(height: 16),
          BellCard(
            title: 'Night bell',
            sound: 'Opening(default)',
            schedule: '9pm to 5am',
            repeat: 'M T W T F S S',
          ),
        ],
      ),
    );
  }
}

class BellCard extends StatelessWidget {
  final String title;
  final String sound;
  final String schedule;
  final String repeat;

  const BellCard({
    super.key,
    required this.title,
    required this.sound,
    required this.schedule,
    required this.repeat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            // Bell Icon
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_outlined,
                color: Colors.orange,
                size: 30,
              ),
            ),
            const SizedBox(width: 20),
            // Bell Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sound: $sound',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Schedule: $schedule',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Repeat: $repeat',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            // Edit Icon
            const Icon(
              Icons.edit,
              color: Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}