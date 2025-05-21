import 'package:e_bell/pages/alarm_page.dart';
import 'package:e_bell/services/calender.dart';
import 'package:e_bell/services/schedule_item.dart';
import 'package:e_bell/tabs/tab_logic1.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:e_bell/alarm/shared_preferences.dart';
import 'package:e_bell/alarm/alarm_model.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TabLogic _tabLogic;
  late CalendarLogic _calendarLogic;
  bool _isFabMenuOpen = false;
  List<AlarmModel> _todaysAlarms = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tabLogic = TabLogic();
    _calendarLogic = CalendarLogic();
    _loadTodaysAlarms();
    // Start timer to refresh UI every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() {}); // Trigger rebuild to update isChecked
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel timer to prevent memory leaks
    super.dispose();
  }

  // Load alarms for today
  Future<void> _loadTodaysAlarms() async {
    final alarms = await SharedPreferencesService.getAlarms();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _todaysAlarms = alarms.where((alarm) {
        final alarmDateTime = DateTime(
          today.year,
          today.month,
          today.day,
          alarm.time.hour,
          alarm.time.minute,
        );
        return isSameDay(alarmDateTime, today) ||
            isSameDay(alarmDateTime.add(const Duration(days: 1)), today);
      }).toList()
        ..sort((a, b) => b.id.compareTo(a.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Bell'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tabs
                  Container(
                    height: 35,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: _tabLogic.buildTab(
                            context: context,
                            text: 'Event / Tasks',
                            index: 0,
                            onTap: () {
                              setState(() {
                                _tabLogic.setSelectedTab(0);
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: _tabLogic.buildTab(
                            context: context,
                            text: 'Bell',
                            index: 1,
                            onTap: () {
                              setState(() {
                                _tabLogic.setSelectedTab(1);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                      firstDay: _calendarLogic.firstDay,
                      lastDay: _calendarLogic.lastDay,
                      focusedDay: _calendarLogic.focusedDay,
                      selectedDayPredicate: (day) {
                        return isSameDay(day, _calendarLogic.selectedDay);
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _calendarLogic.setSelectedDay(selectedDay);
                          _calendarLogic.setFocusedDay(focusedDay);
                          _loadTodaysAlarms();
                        });
                      },
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
                  const SizedBox(height: 16),
                  // Dynamic Schedule Items from Alarms
                  if (_todaysAlarms.isEmpty)
                    const Text(
                      'No alarms scheduled for today',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    )
                  else
                    ..._todaysAlarms.map((alarm) {
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
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // FAB Menu Options
          if (_isFabMenuOpen)
            Positioned(
              bottom: 80,
              right: 16,
              child: Container(
                width: 180,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildFabOption('Reminder', true),
                    _buildFabOption('Alarm', false),
                    _buildFabOption('Bell', false),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isFabMenuOpen = !_isFabMenuOpen;
          });
        },
        backgroundColor: Colors.orange,
        shape: const CircleBorder(),
        child: Icon(
          _isFabMenuOpen ? Icons.close : Icons.edit_calendar_outlined,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Planner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  Widget _buildFabOption(String title, bool isChecked) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          setState(() => _isFabMenuOpen = false);
          switch (title) {
            case 'Alarm':
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AlarmPage()),
              );
              await _loadTodaysAlarms();
              break;
            case 'Reminder':
            // TODO: Implement reminder navigation
              break;
            case 'Bell':
            // TODO: Implement bell navigation
              break;
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}