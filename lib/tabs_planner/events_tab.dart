import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:e_bell/services/schedule_item.dart';
import 'package:e_bell/services/calender.dart';
import 'package:provider/provider.dart';
import '../pages/home_page.dart';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';

class EventsTab extends StatefulWidget {
  final List<AlarmSong> todaysAlarmSongs;
  final CalendarLogic calendarLogic;
  final Function(DateTime, DateTime) onDaySelected;

  const EventsTab({
    super.key,
    required this.todaysAlarmSongs,
    required this.calendarLogic,
    required this.onDaySelected,
  });

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // Use all todaysAlarmSongs as alarms (no alarmType filter)
    final alarmSongs = widget.todaysAlarmSongs;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 350, // Explicit height for TableCalendar
                  margin: const EdgeInsets.all(8.0),
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
                    selectedDayPredicate: (day) => isSameDay(day, widget.calendarLogic.selectedDay),
                    onDaySelected: widget.onDaySelected,
                    calendarFormat: CalendarFormat.month,
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleTextStyle: AppTextStyles.subheading.copyWith(fontWeight: FontWeight.bold),
                      titleCentered: false,
                      leftChevronVisible: true,
                      rightChevronVisible: true,
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: AppTextStyles.small,
                      weekendStyle: AppTextStyles.small,
                      dowTextFormatter: (date, locale) => DateFormat.E(locale).format(date).toUpperCase(),
                    ),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: themeProvider.selectedColor.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: themeProvider.selectedColor,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: themeProvider.selectedColor,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      defaultTextStyle: AppTextStyles.body,
                      weekendTextStyle: AppTextStyles.body,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    isSameDay(widget.calendarLogic.selectedDay, DateTime.now())
                        ? "Today's Alarms"
                        : DateFormat('MMMM d, y').format(widget.calendarLogic.selectedDay),
                    style: AppTextStyles.heading.copyWith(fontSize: 20),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: alarmSongs.isEmpty
                      ? Text(
                    'No alarms scheduled for this day',
                    style: AppTextStyles.body.copyWith(color: Colors.grey),
                  )
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: alarmSongs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final song = entry.value;
                      final timeString = song.getTimeString(context);
                      final isChecked = song.status == 1 && song.isPast(DateTime.now());
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ScheduleItem(
                          time: timeString,
                          title: song.fileName, // Fixed syntax error
                          isChecked: isChecked,
                          isLast: index == alarmSongs.length - 1, // Pass isLast for styling
                          icon: Icons.music_note, // Icon for alarms
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16), // Extra padding at the bottom
              ],
            ),
          ),
        );
      },
    );
  }
}