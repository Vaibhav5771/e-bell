import 'package:e_bell/pages/music_library.dart';
import 'package:e_bell/pages/tablogic1.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:e_bell/pages/alarm_page.dart';
import 'package:e_bell/bell/schedule_bell.dart';
import 'package:e_bell/services/calender.dart';
import 'package:e_bell/alarm/shared_preferences.dart';
import 'package:e_bell/alarm/alarm_model.dart';
import 'package:e_bell/remainder/remainder_page.dart';
import 'dart:async';
import '../profile/profile_page.dart';
import '../tabs_planner/bell_tab.dart';
import '../tabs_planner/events_tab.dart';
import '../tabs_planner/tab_logic1.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TabLogic _tabLogic; // For Planner tabs (Event/Tasks and Bell)
  late TabLogic1 _musicTabLogic; // For Music tabs (Library and My Music)
  late CalendarLogic _calendarLogic;
  bool _isFabMenuOpen = false;
  List<AlarmModel> _todaysAlarms = [];
  Timer? _timer;
  int _selectedIndex = 0; // Tracks the selected bottom nav index

  @override
  void initState() {
    super.initState();
    _tabLogic = TabLogic();
    _musicTabLogic = TabLogic1(); // Initialize shared TabLogic1 instance
    _calendarLogic = CalendarLogic();
    _loadTodaysAlarms();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _calendarLogic.setSelectedDay(selectedDay);
      _calendarLogic.setFocusedDay(focusedDay);
      _loadTodaysAlarms();
    });
  }

  void _onNavBarTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        _musicTabLogic.setSelectedTab(0); // Reset to Library tab when navigating to Library
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // List of screens for each bottom nav tab
    final List<Widget> screens = [
      // Planner Tab (EventsTab or BellTab)
      SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tabs for Events/Tasks and Bell
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
                          print("Switching to Event/Tasks tab");
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
                          print("Switching to Bell tab");
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
              // Show content based on selected tab
              SizedBox(
                height: MediaQuery.of(context).size.height - 200,
                child: _tabLogic.selectedTabIndex == 0
                    ? EventsTab(
                  todaysAlarms: _todaysAlarms,
                  calendarLogic: _calendarLogic,
                  onDaySelected: _onDaySelected,
                  loadTodaysAlarms: _loadTodaysAlarms,
                )
                    : const BellTab(),
              ),
            ],
          ),
        ),
      ),
      // Library Tab (MusicLibrary)
      MusicLibrary(tabLogic: _musicTabLogic),
      // Profile Tab (ProfileScreen)
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'E-Bell',
          style: TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
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
          screens[_selectedIndex],
          // FAB Menu Options (only for Planner tab)
          if (_isFabMenuOpen && _selectedIndex == 0)
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
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
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
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
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
        onTap: _onNavBarTapped,
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
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddReminderScreen()),
              );
              break;
            case 'Bell':
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BellConfigurationScreen()),
              );
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