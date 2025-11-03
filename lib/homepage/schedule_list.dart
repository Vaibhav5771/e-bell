// widgets/home/schedule_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:e_bell/utils/app_text_styles.dart';
import 'package:e_bell/utils/theme_state.dart';
import 'package:e_bell/services/schedule_item.dart';

import '../pages/home_page.dart';

class ScheduleList extends StatelessWidget {
  final bool loading;
  final bool error;
  final List<AlarmSong> alarmSongs;
  final DateTime selectedDay;
  final bool namazEnabled;
  final bool sunriseEnabled;
  final List<String> namazTimes;
  final List<String> poojaTimes;
  final VoidCallback onRefresh;
  final Function(AlarmSong) onDeleteAlarm;
  final Function(AlarmSong) onShowAlarmDetails;

  const ScheduleList({
    Key? key,
    required this.loading,
    required this.error,
    required this.alarmSongs,
    required this.selectedDay,
    required this.namazEnabled,
    required this.sunriseEnabled,
    required this.namazTimes,
    required this.poojaTimes,
    required this.onRefresh,
    required this.onDeleteAlarm,
    required this.onShowAlarmDetails,
  }) : super(key: key);

  String _formatTime(int hour, int minute) {
    return DateFormat.jm().format(DateTime(2000, 1, 1, hour, minute));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'Failed to load alarm songs',
                style: AppTextStyles.body.copyWith(fontSize: 14, color: Colors.red),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: onRefresh,
              tooltip: 'Retry',
            ),
          ],
        ),
      );
    }

    final alarmList = alarmSongs
        .where((s) => s.isScheduledForDay(selectedDay) && s.startTimestamp == 0)
        .toList();
    final reminderList = alarmSongs
        .where((s) => s.isScheduledForDay(selectedDay) && s.startTimestamp != 0)
        .toList();

    debugPrint(
        'Reminders for ${DateFormat('yyyy-MM-dd').format(selectedDay)}: ${reminderList.map((s) => "${s.fileName} @ ${s.hour}:${s.minute}, start: ${s.startTimestamp}, end: ${s.endTimestamp}").join(', ')}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (alarmList.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
            child: Text(
              'Alarms',
              style: AppTextStyles.subheading.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          ...alarmList.asMap().entries.map((entry) {
            final index = entry.key;
            final song = entry.value;
            final timeString = _formatTime(song.hour, song.minute);
            final isChecked = song.status == 1 && song.isPast(selectedDay, DateTime.now());
            final isLast = index == alarmList.length - 1;

            return GestureDetector(
              onLongPress: () => onShowAlarmDetails(song),
              child: ScheduleItem(
                time: timeString,
                title: '', // Empty title
                isChecked: isChecked,
                isLast: isLast,
                icon: Icons.alarm,
                days: song.days,
                selectedColor: themeProvider.selectedColor,
              ),
            );
          }),
        ],
        if (reminderList.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
            child: Text(
              'Reminders',
              style: AppTextStyles.subheading.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          ...reminderList.asMap().entries.map((entry) {
            final index = entry.key;
            final song = entry.value;
            final timeString = _formatTime(song.hour, song.minute);
            final isChecked = song.status == 1 && song.isPast(selectedDay, DateTime.now());
            final isLast = index == reminderList.length - 1;

            return GestureDetector(
              onLongPress: () => onShowAlarmDetails(song),
              child: ScheduleItem(
                time: timeString,
                title: '', // Empty title
                isChecked: isChecked,
                isLast: isLast,
                icon: Icons.notifications_outlined,
                days: song.days,
                selectedColor: themeProvider.selectedColor,
              ),
            );
          }),
        ],
        if (namazEnabled && namazTimes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
            child: Text(
              'Namaz',
              style: AppTextStyles.subheading.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          ...namazTimes.asMap().entries.map((entry) {
            final index = entry.key;
            final t = entry.value;
            return _buildPrayerItem(
              index: index,
              totalItems: namazTimes.length,
              timeString: t,
              defaultFileName: 'Namaz',
              selectedDay: selectedDay,
              icon: Icons.mosque_outlined,
            );
          }),
        ],
        if (sunriseEnabled && poojaTimes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
            child: Text(
              'Sunrise/Sunset',
              style: AppTextStyles.subheading.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          ...poojaTimes.asMap().entries.map((entry) {
            final index = entry.key;
            final t = entry.value;
            return _buildPrayerItem(
              index: index,
              totalItems: poojaTimes.length,
              timeString: t,
              defaultFileName: 'Pooja',
              selectedDay: selectedDay,
              icon: Icons.wb_sunny,
            );
          }),
        ],
        if (alarmList.isEmpty && reminderList.isEmpty && (!namazEnabled || namazTimes.isEmpty) && (!sunriseEnabled || poojaTimes.isEmpty))
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'No alarms or reminders scheduled for this day',
              style: AppTextStyles.body.copyWith(color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildPrayerItem({
    required int index,
    required int totalItems,
    required String timeString,
    required String defaultFileName,
    required DateTime selectedDay,
    required IconData icon,
  }) {
    String fileName;
    int hour = 0;
    int minute = 0;

    try {
      // Normalize ': ' to space for consistent parsing
      final cleaned = timeString.replaceAll(': ', ' ').trim();

      // Regex: Capture label (non-greedy until space before time), then HH:MM [AM/PM]
      final match = RegExp(r'^(.+?)\s+(\d{1,2}):(\d{2})\s*(AM|PM)?$').firstMatch(cleaned);
      if (match == null) {
        throw Exception('Invalid format: No time pattern matched');
      }

      fileName = match.group(1)!.trim();
      if (fileName.isEmpty) fileName = defaultFileName;

      int h = int.parse(match.group(2)!);
      minute = int.parse(match.group(3)!);
      final period = match.group(4)?.toUpperCase();

      // Convert to 24-hour
      if (period == 'PM' && h != 12) {
        h += 12;
      } else if (period == 'AM' && h == 12) {
        h = 0;
      }
      hour = h;

      // Validate
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        throw Exception('Invalid hour/minute values');
      }
    } catch (e) {
      debugPrint('Failed to parse prayer time "$timeString": $e');
      return const SizedBox.shrink();
    }

    final timeStringFormatted = _formatTime(hour, minute);
    final songDateTime = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, hour, minute);
    final isChecked = songDateTime.isBefore(DateTime.now());
    final isLast = index == totalItems - 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ScheduleItem(
        time: timeStringFormatted,
        title: fileName,
        isChecked: isChecked,
        isLast: isLast,
        icon: icon,
      ),
    );
  }
}