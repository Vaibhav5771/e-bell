// widgets/home/calendar_section.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:e_bell/utils/app_text_styles.dart';
import 'package:e_bell/utils/theme_state.dart';
import 'package:e_bell/services/calender.dart';

class CalendarSection extends StatelessWidget {
  final CalendarLogic calendarLogic;
  final DateTime selectedDay;
  final Function(DateTime, DateTime) onDaySelected;
  final Function(DateTime) onPageChanged;

  const CalendarSection({
    Key? key,
    required this.calendarLogic,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
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
        firstDay: calendarLogic.firstDay,
        lastDay: calendarLogic.lastDay,
        focusedDay: calendarLogic.focusedDay,
        selectedDayPredicate: (day) => isSameDay(day, selectedDay),
        onDaySelected: onDaySelected,
        onPageChanged: onPageChanged,
        calendarFormat: CalendarFormat.week,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleTextStyle: AppTextStyles.subheading.copyWith(
            fontWeight: FontWeight.bold,
          ),
          titleCentered: false,
          leftChevronVisible: true,
          rightChevronVisible: true,
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: AppTextStyles.small,
          weekendStyle: AppTextStyles.small,
          dowTextFormatter: (date, locale) =>
              DateFormat.E(locale).format(date).toUpperCase(),
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.grey[300],
            shape: BoxShape.circle,
          ),
          todayTextStyle: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.bold,
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
    );
  }
}