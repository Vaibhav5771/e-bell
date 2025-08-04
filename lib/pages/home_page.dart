import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:e_bell/pages/alarm_page.dart';
import 'package:e_bell/pages/music_library.dart';
import 'package:e_bell/pages/tablogic1.dart';
import 'package:e_bell/bell/schedule_bell.dart';
import 'package:e_bell/services/calender.dart';
import 'package:e_bell/alarm/shared_preferences.dart';
import 'package:e_bell/alarm/alarm_model.dart';
import 'package:e_bell/remainder/remainder_page.dart';
import 'package:location/location.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../profile/profile_page.dart';
import '../remainder/remainder_model.dart';
import '../remainder/shared_preferences_remainder.dart';
import '../services/bell_service.dart';
import '../services/theme_state.dart';
import '../tabs_planner/bell_tab.dart';
import '../tabs_planner/events_tab.dart';
import '../tabs_planner/tab_logic1.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../test/auth_service.dart';
import 'namaz_Sunrise.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TabLogic _tabLogic;
  late TabLogic1 _musicTabLogic;
  late CalendarLogic _calendarLogic;
  bool _isFabMenuOpen = false;
  List<AlarmModel> _todaysAlarms = [];
  List<ReminderModel> _todaysReminders = [];
  Timer? _timer;
  int _selectedIndex = 0;
  String connectionStatus = "Checking Wi-Fi...";
  bool isWifiConnected = false;
  Timer? wifiCheckTimer;
  final String targetSsid = "IoGen_Speaker";
  bool _hasSynced = false;

  @override
  void initState() {
    super.initState();
    _tabLogic = TabLogic();
    _musicTabLogic = TabLogic1();
    _calendarLogic = CalendarLogic();
    _loadTodaysAlarms();
    _loadRemindersForSelectedDay();
    _requestPermissions();
    _startWifiMonitoring().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoSyncTime();
      });
    });
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() {
        _loadTodaysAlarms();
        _loadRemindersForSelectedDay();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    wifiCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    Location location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        setState(() {
          connectionStatus = "Location service is disabled";
        });
        _showLocationServiceDialog();
        return;
      }
    }

    var status = await Permission.location.request();
    if (status.isDenied) {
      setState(() {
        connectionStatus = "Location permission denied";
      });
      _showPermissionDialog();
    } else if (status.isPermanentlyDenied) {
      setState(() {
        connectionStatus = "Location permission permanently denied";
      });
      _showPermissionDialog();
    } else {
      debugPrint("Location permission granted");
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Location Service Required"),
        content: const Text(
          "E-Bell needs location services to detect Wi-Fi networks. "
              "Please enable location services in your device settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Location Permission Required"),
        content: const Text(
          "E-Bell needs location permission to sync with the bell. "
              "Please grant this permission in app settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  Future<void> _startWifiMonitoring() async {
    await _checkWifiConnection();
    wifiCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkWifiConnection();
    });
  }

  Future<void> _checkWifiConnection() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        String? wifiSSID = await NetworkInfo().getWifiName();
        String? cleanedSSID = wifiSSID?.replaceAll('"', '').trim();
        debugPrint("Raw Wi-Fi SSID: $wifiSSID");
        debugPrint("Cleaned Wi-Fi SSID: $cleanedSSID");
        setState(() {
          isWifiConnected = true;
          if (cleanedSSID != null &&
              cleanedSSID.toLowerCase() == targetSsid.toLowerCase()) {
            connectionStatus = "Connected to $targetSsid";
            if (!_hasSynced) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _autoSyncTime();
              });
            }
          } else {
            connectionStatus = "Connected to Wi-Fi: ${cleanedSSID ?? 'Unknown'}";
            _hasSynced = false;
          }
        });
      } else {
        setState(() {
          isWifiConnected = false;
          connectionStatus = "Not connected to Wi-Fi";
          _hasSynced = false;
        });
      }
    } catch (e) {
      setState(() {
        isWifiConnected = false;
        connectionStatus = "Error checking Wi-Fi: $e";
        _hasSynced = false;
      });
      debugPrint("Error checking Wi-Fi: $e");
    }
  }

  Future<void> _autoSyncTime() async {
    if (_hasSynced) return;
    debugPrint(
        "Attempting auto-sync with isWifiConnected: $isWifiConnected, connectionStatus: $connectionStatus");
    if (isWifiConnected && connectionStatus.contains(targetSsid)) {
      setState(() => _hasSynced = true);
      await Future.delayed(const Duration(milliseconds: 500));
      await BellService().syncTime(context);
    }
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

  Future<void> _loadRemindersForSelectedDay() async {
    final reminders = await ReminderSharedPreferencesService.getReminders();
    final selectedDay = _calendarLogic.selectedDay;
    setState(() {
      _todaysReminders = reminders.where((reminder) {
        final reminderDate = DateTime(
          reminder.startDateTime.year,
          reminder.startDateTime.month,
          reminder.startDateTime.day,
        );
        return isSameDay(reminderDate, selectedDay);
      }).toList()
        ..sort((a, b) => b.id.compareTo(a.id));
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _calendarLogic.setSelectedDay(selectedDay);
      _calendarLogic.setFocusedDay(focusedDay);
      _loadTodaysAlarms();
      _loadRemindersForSelectedDay();
    });
  }

  void _onNavBarTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        _musicTabLogic.setSelectedTab(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final List<Widget> screens = [
      SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                          debugPrint("Switching to Event/Tasks tab");
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
                          debugPrint("Switching to Bell tab");
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
              Text(
                connectionStatus,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: MediaQuery.of(context).size.height - 200,
                child: _tabLogic.selectedTabIndex == 0
                    ? EventsTab(
                  todaysAlarms: _todaysAlarms,
                  todaysReminders: _todaysReminders,
                  calendarLogic: _calendarLogic,
                  onDaySelected: _onDaySelected,
                  loadTodaysAlarms: _loadTodaysAlarms,
                  loadTodaysReminders: _loadRemindersForSelectedDay,
                )
                    : const BellTab(),
              ),
            ],
          ),
        ),
      ),
      MusicLibrary(tabLogic: _musicTabLogic),
      ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'E-Bell',
          style: TextStyle(
            color: themeProvider.selectedColor,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
      ),
      body: Stack(
        children: [
          screens[_selectedIndex],
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
                    _buildFabOption('Regional Planner', false),
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
        backgroundColor: themeProvider.selectedColor,
        shape: const CircleBorder(),
        child: Icon(
          _isFabMenuOpen ? Icons.close : Icons.edit_calendar_outlined,
          color: Colors.white,
        ),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      bottomNavigationBar: SizedBox(
        height: 66,
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onNavBarTapped,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: themeProvider.selectedColor,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              label: 'Planner',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.music_note),
              label: 'Library',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFabOption(String title, bool isChecked) {
    final themeProvider = Provider.of<ThemeProvider>(context);
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
                MaterialPageRoute(builder: (context) => const ReminderPage()),
              );
              await _loadRemindersForSelectedDay();
              break;
            case 'Regional Planner':
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReligiousAlarms()),
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
                decoration: BoxDecoration(
                  color: themeProvider.selectedColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 16),
              (title == 'Regional Planner')
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Regional',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Planner',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              )
                  : Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}