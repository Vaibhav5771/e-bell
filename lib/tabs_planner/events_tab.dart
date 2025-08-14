import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/schedule_item.dart';
import '../alarm/alarm_model.dart';
import '../services/calender.dart';
import '../remainder/remainder_model.dart';
import '../services/theme_state.dart';

class EventsTab extends StatefulWidget {
  final List<AlarmModel> todaysAlarms;
  final List<ReminderModel> todaysReminders;
  final CalendarLogic calendarLogic;
  final Function(DateTime, DateTime) onDaySelected;
  final Future<void> Function() loadTodaysAlarms;
  final Future<void> Function() loadTodaysReminders;

  const EventsTab({
    super.key,
    required this.todaysAlarms,
    required this.todaysReminders,
    required this.calendarLogic,
    required this.onDaySelected,
    required this.loadTodaysAlarms,
    required this.loadTodaysReminders,
  });

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  bool _namazEnabled = false;
  bool _sunriseEnabled = false;
  bool _loadingPrayerStatus = false;
  bool _errorLoadingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadPrayerTimesStatus();
  }

  Future<Map<String, bool>> _checkPrayerTimesStatus() async {
    try {
      final client = http.Client();
      final response = await client.get(
        Uri.parse('http://192.168.2.1/'),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          client.close();
          throw Exception('Connection timed out');
        },
      );

      try {
        if (response.statusCode == 200) {
          final jsonData = jsonDecode(response.body);
          final alarmData = jsonData['alarmData'] as List<dynamic>?;

          debugPrint('Raw alarmData: $alarmData');

          bool namazEnabled = false;
          bool sunriseEnabled = false;

          if (alarmData != null && alarmData.isNotEmpty) {
            final files = (alarmData[0]['Filenames'] as List<dynamic>?) ?? [];

            debugPrint('Filenames: $files');

            for (var file in files) {
              if (file is List && file.length >= 4) {
                final filename = file[0].toString().toLowerCase();
                final isEnabled = file[3] == 1; // Check R field instead of A

                debugPrint('Processing file: $filename, enabled: $isEnabled');

                if (filename.startsWith('namaz/') && !filename.contains('sunrise') && !filename.contains('sunset')) {
                  namazEnabled = namazEnabled || isEnabled;
                } else if (filename.contains('sunrise') || filename.contains('sunset')) {
                  sunriseEnabled = sunriseEnabled || isEnabled;
                }
              }
            }
          }

          debugPrint('namazEnabled: $namazEnabled, sunriseEnabled: $sunriseEnabled');

          return {
            'namazEnabled': namazEnabled,
            'sunriseEnabled': sunriseEnabled,
          };
        } else {
          throw Exception('HTTP ${response.statusCode} error');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Error: $e');
      throw Exception('Failed to check prayer times status: $e');
    }
  }

  Future<void> _loadPrayerTimesStatus() async {
    if (!mounted) return;

    setState(() {
      _loadingPrayerStatus = true;
      _errorLoadingStatus = false;
    });

    try {
      final status = await _checkPrayerTimesStatus();
      if (!mounted) return;

      setState(() {
        _namazEnabled = status['namazEnabled'] ?? false;
        _sunriseEnabled = status['sunriseEnabled'] ?? false;
        _loadingPrayerStatus = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPrayerStatus = false;
        _errorLoadingStatus = true;
      });

      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildPrayerTimeIndicator({required String label, required bool enabled}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 8),
      constraints: const BoxConstraints(minWidth: 80),
      decoration: BoxDecoration(
        color: enabled ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.circle,
            color: enabled ? Colors.green : Colors.grey,
            size: 14,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.green : Colors.grey,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicators() {
    if (_loadingPrayerStatus) {
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

    if (_errorLoadingStatus) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'Failed to load status',
                style: const TextStyle(color: Colors.red, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _loadPrayerTimesStatus,
              tooltip: 'Retry',
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildPrayerTimeIndicator(
              label: 'Namaz Times',
              enabled: _namazEnabled,
            ),
            _buildPrayerTimeIndicator(
              label: 'Sunrise/Sunset',
              enabled: _sunriseEnabled,
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _loadPrayerTimesStatus,
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final today = DateTime.now();
    final selectedDay = widget.calendarLogic.selectedDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Calendar
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 5,
              ),
            ],
          ),
          child: TableCalendar(
            firstDay: widget.calendarLogic.firstDay,
            lastDay: widget.calendarLogic.lastDay,
            focusedDay: widget.calendarLogic.focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, selectedDay),
            onDaySelected: widget.onDaySelected,
            calendarFormat: CalendarFormat.month,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleTextStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              titleCentered: false,
              leftChevronVisible: true,
              rightChevronVisible: true,
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: const TextStyle(color: Colors.black54),
              weekendStyle: const TextStyle(color: Colors.black54),
              dowTextFormatter: (date, locale) =>
                  DateFormat.E(locale).format(date).toUpperCase(),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 16,
              ),
              selectedDecoration: BoxDecoration(
                color: themeProvider.selectedColor,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 16,
              ),
              defaultTextStyle: const TextStyle(
                color: Colors.black,
                fontSize: 16,
              ),
              weekendTextStyle: const TextStyle(
                color: Colors.black,
                fontSize: 16,
              ),
            ),
          ),
        ),

        // Prayer Times Status Indicators
        _buildStatusIndicators(),

        // Schedule Header
        Text(
          isSameDay(selectedDay, today)
              ? "Today's Schedule"
              : DateFormat('MMMM d, y').format(selectedDay),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Schedule Items
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.todaysAlarms.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      'Alarms',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  ...widget.todaysAlarms.asMap().entries.map((entry) {
                    final index = entry.key;
                    final alarm = entry.value;
                    final alarmDateTime = DateTime(
                      selectedDay.year,
                      selectedDay.month,
                      selectedDay.day,
                      alarm.time.hour,
                      alarm.time.minute,
                    );
                    final isChecked = alarmDateTime.isBefore(DateTime.now());
                    final timeString = alarm.time.format(context);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ScheduleItem(
                        time: timeString,
                        title: alarm.label,
                        isChecked: isChecked,
                        isLast: index == widget.todaysAlarms.length - 1,
                        icon: Icons.alarm,
                      ),
                    );
                  }),
                ],
                if (widget.todaysReminders.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 8, bottom: 8),
                    child: Text(
                      'Reminders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  ...widget.todaysReminders.asMap().entries.map((entry) {
                    final index = entry.key;
                    final reminder = entry.value;
                    final timeString =
                        '${DateFormat('HH:mm').format(reminder.startDateTime)} - ${DateFormat('HH:mm').format(reminder.endDateTime)}';
                    final isChecked = reminder.endDateTime.isBefore(DateTime.now());
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ScheduleItem(
                        time: timeString,
                        title: reminder.title,
                        isChecked: isChecked,
                        isLast: index == widget.todaysReminders.length - 1,
                        icon: Icons.event,
                      ),
                    );
                  }),
                ],
                if (widget.todaysAlarms.isEmpty && widget.todaysReminders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'No alarms or reminders scheduled for this day',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}