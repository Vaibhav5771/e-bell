import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:location/location.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:e_bell/pages/alarm_page.dart';
import 'package:e_bell/pages/music_library.dart';
import 'package:e_bell/pages/tablogic1.dart';
import 'package:e_bell/bell/schedule_bell.dart';
import 'package:e_bell/services/calender.dart';
import 'package:e_bell/alarm/shared_preferences.dart';
import 'package:e_bell/alarm/alarm_model.dart';
import 'package:e_bell/remainder/remainder_page.dart';
import 'package:e_bell/remainder/remainder_model.dart';
import 'package:e_bell/remainder/shared_preferences_remainder.dart';
import 'package:e_bell/services/bell_service.dart';
import 'package:e_bell/services/theme_state.dart';
import 'package:e_bell/tabs_planner/bell_tab.dart';
import 'package:e_bell/tabs_planner/tab_logic1.dart';
import 'package:e_bell/profile/profile_page.dart';
import 'package:e_bell/pages/namaz_Sunrise.dart';
import 'dart:async';
import '../services/schedule_item.dart';

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
  bool _namazEnabled = false;
  bool _sunriseEnabled = false;
  bool _loadingPrayerStatus = false;
  bool _errorLoadingStatus = false;
  final GlobalKey _calendarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabLogic = TabLogic();
    _musicTabLogic = TabLogic1();
    _calendarLogic = CalendarLogic();
    _loadTodaysAlarms();
    _loadRemindersForSelectedDay();
    _requestPermissions();
    _startWifiMonitoring();
    _loadPrayerTimesStatus();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      // Only update data without rebuilding the entire UI unnecessarily
      _loadTodaysAlarms();
      _loadRemindersForSelectedDay();
      _loadPrayerTimesStatus();
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
          } else {
            connectionStatus = "Connected to Wi-Fi: ${cleanedSSID ?? 'Unknown'}";
          }
        });
      } else {
        setState(() {
          isWifiConnected = false;
          connectionStatus = "Not connected to Wi-Fi";
        });
      }
    } catch (e) {
      setState(() {
        isWifiConnected = false;
        connectionStatus = "Error checking Wi-Fi: $e";
      });
      debugPrint("Error checking Wi-Fi: $e");
    }
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
                final isEnabled = file[3] == 1;

                debugPrint('Processing file: $filename, enabled: $isEnabled');

                if (filename.startsWith('namaz/') &&
                    !filename.contains('sunrise') &&
                    !filename.contains('sunset')) {
                  namazEnabled = namazEnabled || isEnabled;
                } else if (filename.contains('sunrise') ||
                    filename.contains('sunset')) {
                  sunriseEnabled = sunriseEnabled || isEnabled;
                }
              }
            }
          }

          debugPrint(
              'namazEnabled: $namazEnabled, sunriseEnabled: $sunriseEnabled');

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
      if (!isWifiConnected || !connectionStatus.contains(targetSsid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Please connect to IoGen_Speaker Wi-Fi to sync time")),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Selected time is in the past. Setting for tomorrow: ${selectedTime.format(context)}",
            ),
          ),
        );
      }
      try {
        await BellService().syncTime(context, selectedTime: selectedDateTime);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
              Text("Time synced successfully: ${selectedTime.format(context)}")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to sync time: $e")),
        );
      }
    }
  }

  Future<void> _loadTodaysAlarms() async {
    final alarms = await SharedPreferencesService.getAlarms();
    final selectedDay = _calendarLogic.selectedDay;
    setState(() {
      _todaysAlarms = alarms.where((alarm) {
        final alarmDateTime = DateTime(
          selectedDay.year,
          selectedDay.month,
          selectedDay.day,
          alarm.time.hour,
          alarm.time.minute,
        );
        return isSameDay(alarmDateTime, selectedDay);
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

  void _onPageChanged(DateTime focusedDay) {
    // Update focusedDay when the user navigates to a new week
    if (!mounted) return;
    setState(() {
      _calendarLogic.setFocusedDay(focusedDay);
      // Optionally update selectedDay to the first day of the new week
      _calendarLogic.setSelectedDay(focusedDay);
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
      _isFabMenuOpen = false;
    });
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
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _tabLogic.selectedTabIndex == 0
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    key: _calendarKey,
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
                      selectedDayPredicate: (day) => isSameDay(day, selectedDay),
                      onDaySelected: _onDaySelected,
                      onPageChanged: _onPageChanged, // Handle week navigation
                      calendarFormat: CalendarFormat.week,
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
                  const SizedBox(height: 16),
                  // Static Schedule Section
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
                          // Prayer Time Indicators
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_todaysAlarms.isNotEmpty) ...[
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
                                ..._todaysAlarms.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final alarm = entry.value;
                                  final alarmDateTime = DateTime(
                                    selectedDay.year,
                                    selectedDay.month,
                                    selectedDay.day,
                                    alarm.time.hour,
                                    alarm.time.minute,
                                  );
                                  final isChecked =
                                  alarmDateTime.isBefore(DateTime.now());
                                  final timeString = alarm.time.format(context);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: ScheduleItem(
                                      time: timeString,
                                      title: alarm.label,
                                      isChecked: isChecked,
                                      isLast: index == _todaysAlarms.length - 1,
                                      icon: Icons.alarm,
                                    ),
                                  );
                                }),
                              ],
                              if (_todaysReminders.isNotEmpty) ...[
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
                                ..._todaysReminders.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final reminder = entry.value;
                                  final timeString =
                                      '${DateFormat('HH:mm').format(reminder.startDateTime)} - ${DateFormat('HH:mm').format(reminder.endDateTime)}';
                                  final isChecked =
                                  reminder.endDateTime.isBefore(DateTime.now());
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: ScheduleItem(
                                      time: timeString,
                                      title: reminder.title,
                                      isChecked: isChecked,
                                      isLast: index == _todaysReminders.length - 1,
                                      icon: Icons.event,
                                    ),
                                  );
                                }),
                              ],
                              if (_todaysAlarms.isEmpty && _todaysReminders.isEmpty)
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
                        ],
                      ),
                    ),
                  ),
                ],
              )
                  : const BellTab(),
              // Ensure content is scrollable
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
        title: Text(
          'E-Bell',
          style: TextStyle(
            color: themeProvider.selectedColor,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.access_time,
              color: themeProvider.selectedColor,
            ),
            tooltip: 'Sync Time',
            onPressed: _showTimePickerAndSync,
          ),
        ],
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                    ),
                  ],
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
}