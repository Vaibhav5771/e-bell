// models/alarm_song.dart
import 'package:flutter/material.dart';

class AlarmSong {
  final String fileName;
  final int hour;
  final int minute;
  final int startTimestamp;
  final int endTimestamp;
  final int status;
  final int days;

  AlarmSong({
    required this.fileName,
    required this.hour,
    required this.minute,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.status,
    required this.days,
  });

  factory AlarmSong.fromJson(List<dynamic> json) {
    return AlarmSong(
      fileName: json[0] as String,
      hour: json[1] as int,
      minute: json[2] as int,
      startTimestamp: json[3] as int,
      endTimestamp: json[4] as int,
      status: json[5] as int,
      days: json[6] as int,
    );
  }

  bool isScheduledForDay(DateTime day) {
    final weekday = day.weekday;
    int bitPosition;
    if (weekday == 7) {
      bitPosition = 7;
    } else {
      bitPosition = weekday;
    }
    final dayBit = 1 << bitPosition;
    final dayMatches = (days & dayBit) != 0;

    bool inRange = true;
    if (startTimestamp != 0 || endTimestamp != 0) {
      DateTime? startDT;
      if (startTimestamp != 0) {
        startDT = DateTime.fromMillisecondsSinceEpoch(startTimestamp * 1000);
      }
      DateTime? endDT;
      if (endTimestamp != 0) {
        endDT = DateTime.fromMillisecondsSinceEpoch(endTimestamp * 1000);
      } else if (startDT != null) {
        endDT = startDT;
      } else {
        inRange = false;
      }
      if (inRange) {
        final dayDate = DateTime(day.year, day.month, day.day);
        final startDate = DateTime(startDT!.year, startDT.month, startDT.day);
        final endDate = DateTime(endDT!.year, endDT.month, endDT.day);
        inRange = !dayDate.isBefore(startDate) && !dayDate.isAfter(endDate);
      }
    }
    final isScheduled = inRange && dayMatches;
    debugPrint(
        'Song: $fileName, Time: $hour:$minute, Days: $days (binary: ${days.toRadixString(2)}), '
            'Weekday: $weekday, BitPosition: $bitPosition, DayBit: $dayBit, '
            'Scheduled: $isScheduled');
    return isScheduled;
  }

  String getTimeString(BuildContext context) {
    return TimeOfDay(hour: hour, minute: minute).format(context);
  }

  bool isPast(DateTime day, DateTime now) {
    final songDateTime = DateTime(day.year, day.month, day.day, hour, minute);
    return songDateTime.isBefore(now);
  }
}