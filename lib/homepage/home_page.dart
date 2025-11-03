// pages/home_screen.dart
import 'package:e_bell/homepage/schedule_list.dart';
import 'package:e_bell/homepage/status_indicators.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:e_bell/utils/app_text_styles.dart';
import 'package:e_bell/utils/theme_state.dart';
import 'package:e_bell/pages/music_library.dart';
import 'package:e_bell/profile/profile_page.dart';
import 'package:e_bell/tabs_planner/bell_tab.dart';
import 'package:e_bell/pages/tablogic1.dart';
import 'package:e_bell/services/calender.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:async';

import '../pages/home_page.dart';
import '../tabs_planner/tab_logic1.dart';
import 'calender_section.dart';
import 'fab_menu.dart';
import 'home_services.dart';
import 'navigation_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // State variables
  List<String> _namazTimes = [];
  List<String> _poojaTimes = [];
  bool _isFabMenuOpen = false;
  List<AlarmSong> _alarmSongs = [];
  bool _loadingAlarmSongs = false;
  bool _errorLoadingAlarmSongs = false;
  Timer? _timer;
  int _selectedIndex = 0;
  String connectionStatus = "Checking Wi-Fi...";
  bool isWifiConnected = false;
  Timer? wifiCheckTimer;
  bool _namazEnabled = false;
  bool _sunriseEnabled = false;
  bool _loadingPrayerStatus = false;
  bool _errorLoadingStatus = false;

  // Tab and calendar logic
  late TabLogic _tabLogic;
  late TabLogic1 _musicTabLogic;
  late CalendarLogic _calendarLogic;

  String _previousConnectionStatus = "";
  String _previousWifiSSID = "";

  @override
  void initState() {
    super.initState();
    _tabLogic = TabLogic();
    _musicTabLogic = TabLogic1();
    _calendarLogic = CalendarLogic();
    _initializeApp();
    _requestPermissions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    wifiCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _startWifiMonitoring();
    await Future.delayed(const Duration(milliseconds: 3000));
    await _loadPrayerTimesStatus();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadPrayerTimesStatus();
    });
  }

  Future<void> _requestPermissions() async {
    try {
      await HomeServices.requestPermissions();
      debugPrint("Location permission granted");
    } catch (e) {
      setState(() {
        connectionStatus = e.toString();
      });
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Location Permission Required", style: AppTextStyles.heading),
        content: Text(
          "E-Bell needs location permission to sync with the bell. "
              "Please grant this permission in app settings.",
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: AppTextStyles.button.copyWith(color: Colors.black)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: Text("Open Settings", style: AppTextStyles.button.copyWith(color: Colors.black)),
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
    final wifiStatus = await HomeServices.checkWifiConnection();

    setState(() {
      isWifiConnected = wifiStatus.isConnected;
      connectionStatus = wifiStatus.status;
    });

    bool justConnectedToTarget = wifiStatus.isTargetWifi &&
        (_previousWifiSSID != wifiStatus.ssid ||
            !_previousConnectionStatus.contains(HomeServices.targetSsid));

    if (wifiStatus.isTargetWifi && justConnectedToTarget && mounted) {
      debugPrint("Newly connected to target Wi-Fi, loading data...");
      _loadPrayerTimesStatus();
    }

    _previousWifiSSID = wifiStatus.ssid;
    _previousConnectionStatus = connectionStatus;
  }

  Future<void> _loadPrayerTimesStatus() async {
    if (!mounted) return;

    if (!isWifiConnected || !connectionStatus.contains(HomeServices.targetSsid)) {
      setState(() {
        _loadingPrayerStatus = false;
        _errorLoadingStatus = true;
        _loadingAlarmSongs = false;
        _errorLoadingAlarmSongs = true;
      });
      _showSnackBar('Please connect to IoGen_Speaker Wi-Fi to fetch data');
      return;
    }

    setState(() {
      _loadingPrayerStatus = true;
      _errorLoadingStatus = false;
      _loadingAlarmSongs = true;
      _errorLoadingAlarmSongs = false;
    });

    try {
      final regionStatus = await HomeServices.fetchRegionStatus();
      final regtimeData = await HomeServices.checkPrayerTimesStatus();

      if (!mounted) return;
      setState(() {
        _namazEnabled = regionStatus['namazEnabled'] ?? false;
        _sunriseEnabled = regionStatus['sunriseEnabled'] ?? false;
        _alarmSongs = (regionStatus['alarmSongs'] as List<AlarmSong>)
          ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
        _namazTimes = regtimeData['namazTimes'] ?? [];
        _poojaTimes = regtimeData['poojaTimes'] ?? [];
        _loadingPrayerStatus = false;
        _loadingAlarmSongs = false;
      });
      debugPrint('Loaded ${_alarmSongs.length} alarm songs for display');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPrayerStatus = false;
        _errorLoadingStatus = true;
        _loadingAlarmSongs = false;
        _errorLoadingAlarmSongs = true;
      });
      _showSnackBar(e.toString());
    }
  }

  Future<void> _deleteAlarm(AlarmSong alarm) async {
    if (!isWifiConnected || !connectionStatus.contains(HomeServices.targetSsid)) {
      _showSnackBar("Please connect to IoGen_Speaker Wi-Fi to delete alarm");
      return;
    }

    try {
      await HomeServices.deleteAlarm(alarm);
      setState(() {
        _alarmSongs.remove(alarm);
      });
      _showSnackBar("Alarm deleted successfully");
      await _loadPrayerTimesStatus();
    } catch (e) {
      _showSnackBar("Failed to delete alarm: $e");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: AppTextStyles.body)),
    );
  }

  Future<void> _showTimePickerAndSync() async {
    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      if (!isWifiConnected || !connectionStatus.contains(HomeServices.targetSsid)) {
        _showSnackBar("Please connect to IoGen_Speaker Wi-Fi to sync time");
        return;
      }
      final now = DateTime.now();
      DateTime selectedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      if (selectedDateTime.isBefore(now)) {
        selectedDateTime = selectedDateTime.add(const Duration(days: 1));
        _showSnackBar("Selected time is in the past. Setting for tomorrow: ${selectedTime.format(context)}");
      }
      try {
        await HomeServices.syncTime(selectedDateTime);
        _showSnackBar("Time synced successfully: ${selectedTime.format(context)}");
      } catch (e) {
        _showSnackBar("Failed to sync time: $e");
      }
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _calendarLogic.setSelectedDay(selectedDay);
      _calendarLogic.setFocusedDay(focusedDay);
    });
  }

  void _onPageChanged(DateTime focusedDay) {
    if (!mounted) return;
    setState(() {
      _calendarLogic.setFocusedDay(focusedDay);
      _calendarLogic.setSelectedDay(focusedDay);
    });
  }

  void _onNavBarTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        _musicTabLogic.setSelectedTab(0);
      }
      _isFabMenuOpen = false;
    });
  }

  void _showAlarmDetailsDialog(AlarmSong alarm) {
    final selectedColor = Provider.of<ThemeProvider>(context, listen: false).selectedColor;

    String rawTime = "${alarm.hour % 12 == 0 ? 12 : alarm.hour % 12}:${alarm.minute.toString().padLeft(2, '0')}";
    String period = alarm.hour >= 12 ? "PM" : "AM";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                rawTime,
                style: AppTextStyles.headingheading,
              ),
              const SizedBox(width: 4.0),
              Text(
                period,
                style: AppTextStyles.heading.copyWith(
                  color: selectedColor,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            _buildDaysRow(alarm.days, selectedColor),
            const SizedBox(height: 16),
            Text(
              alarm.fileName,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteAlarm(alarm);
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.red,
                backgroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(
                "Delete",
                style: AppTextStyles.button.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysRow(int days, Color selectedColor) {
    final List<String> abbr = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final List<int> bits = [1, 2, 3, 4, 5, 6, 7];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (i) {
        final bool active = (days & (1 << bits[i])) != 0;
        return Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: Text(
            abbr[i],
            style: AppTextStyles.subheading.copyWith(
              color: active ? selectedColor : Colors.grey,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final today = DateTime.now();
    final selectedDay = _calendarLogic.selectedDay;

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
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _tabLogic.selectedTabIndex == 0
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CalendarSection(
                    calendarLogic: _calendarLogic,
                    selectedDay: selectedDay,
                    onDaySelected: _onDaySelected,
                    onPageChanged: _onPageChanged,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusIndicators(
                            loading: _loadingPrayerStatus,
                            error: _errorLoadingStatus,
                            namazEnabled: _namazEnabled,
                            sunriseEnabled: _sunriseEnabled,
                            namazTimes: _namazTimes,
                            poojaTimes: _poojaTimes,
                            onRefresh: _loadPrayerTimesStatus,
                          ),
                          Text(
                            isSameDay(selectedDay, today)
                                ? "Today's Schedule"
                                : DateFormat('MMMM d, y').format(selectedDay),
                            style: AppTextStyles.subheading,
                          ),
                          const SizedBox(height: 12),
                          ScheduleList(
                            loading: _loadingAlarmSongs,
                            error: _errorLoadingAlarmSongs,
                            alarmSongs: _alarmSongs,
                            selectedDay: selectedDay,
                            namazEnabled: _namazEnabled,
                            sunriseEnabled: _sunriseEnabled,
                            namazTimes: _namazTimes,
                            poojaTimes: _poojaTimes,
                            onRefresh: _loadPrayerTimesStatus,
                            onDeleteAlarm: _deleteAlarm,
                            onShowAlarmDetails: _showAlarmDetailsDialog,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
                  : const BellTab(),
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
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
        title: Image.asset(
          'assets/appbar_icon.png',
          height: 40,
          fit: BoxFit.contain,
        ),
      ),
      body: Stack(
        children: [
          screens[_selectedIndex],
          if (_isFabMenuOpen && _selectedIndex == 0)
            FabMenu(
              isOpen: _isFabMenuOpen,
              onClose: () => setState(() => _isFabMenuOpen = false),
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
          size: 28,
        ),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      bottomNavigationBar: CustomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavBarTapped,
        themeProvider: themeProvider,
      ),
    );
  }
}