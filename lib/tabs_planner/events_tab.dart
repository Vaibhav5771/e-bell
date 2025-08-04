import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:e_bell/services/schedule_item.dart';
import 'package:e_bell/alarm/alarm_model.dart';
import 'package:e_bell/services/calender.dart';
import 'package:provider/provider.dart';
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
              dowTextFormatter: (date, locale) => DateFormat.E(locale).format(date).toUpperCase(),
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
        const SizedBox(height: 24),
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
        // Scrollable Schedule Items
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Alarms Section
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
                        isLast: index == widget.todaysAlarms.length - 1, // Set isLast
                        icon: Icons.alarm, // Explicitly set alarm icon
                      ),
                    );
                  }),
                ],
                // Reminders Section
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
                        isLast: index == widget.todaysReminders.length - 1, // Set isLast
                        icon: Icons.event, // Use event icon for reminders
                      ),
                    );
                  }),
                ],
                // Empty State
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