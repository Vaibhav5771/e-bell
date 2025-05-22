import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:e_bell/services/schedule_item.dart';
import 'package:e_bell/alarm/alarm_model.dart';
import 'package:e_bell/services/calender.dart';

class EventsTab extends StatefulWidget {
  final List<AlarmModel> todaysAlarms;
  final CalendarLogic calendarLogic;
  final Function(DateTime, DateTime) onDaySelected;
  final Future<void> Function() loadTodaysAlarms;

  const EventsTab({
    super.key,
    required this.todaysAlarms,
    required this.calendarLogic,
    required this.onDaySelected,
    required this.loadTodaysAlarms,
  });

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  @override
  Widget build(BuildContext context) {
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
            selectedDayPredicate: (day) {
              return isSameDay(day, widget.calendarLogic.selectedDay);
            },
            onDaySelected: widget.onDaySelected,
            calendarFormat: CalendarFormat.month,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleTextStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              leftChevronVisible: true,
              rightChevronVisible: true,
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: Colors.black54),
              weekendStyle: TextStyle(color: Colors.black54),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              todayTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.orange[300],
                shape: BoxShape.circle,
              ),
              defaultTextStyle: const TextStyle(color: Colors.black54),
              weekendTextStyle: const TextStyle(color: Colors.black54),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Today's Schedule
        const Text(
          "Today's Schedule",
          style: TextStyle(
            fontSize: 18,
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
              children: widget.todaysAlarms.isEmpty
                  ? [
                      const Text(
                        'No alarms scheduled for today',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ]
                  : widget.todaysAlarms.map((alarm) {
                      final alarmDateTime = DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
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
                        ),
                      );
                    }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
