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
import 'package:e_bell/pages/music_library.dart';
import 'package:e_bell/pages/tablogic1.dart';
import 'package:e_bell/bell/schedule_bell.dart';
import 'package:e_bell/services/calender.dart';
import 'package:e_bell/remainder/remainder_page.dart';
import 'package:e_bell/services/services.dart';
import 'package:e_bell/utils/theme_state.dart';
import 'package:e_bell/tabs_planner/bell_tab.dart';
import 'package:e_bell/tabs_planner/tab_logic1.dart';
import 'package:e_bell/profile/profile_page.dart';
import 'package:e_bell/pages/namaz_Sunrise.dart';
import 'dart:async';
import '../alarm/alarm_page.dart';
import '../services/schedule_item.dart';
import '../utils/app_text_styles.dart';

class AlarmSong {
  final String fileName;
  final int hour;
  final int minute;
  final int startTimestamp; // Unix timestamp
  final int endTimestamp; // Unix timestamp (0 if not applicable)
  final int status; // Assuming 1 means active/played
  final int days; // Bitmask for days of the week

  AlarmSong({
    required this.fileName,
    required this.hour,
    required this.minute,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.status,
    required this.days,
  });

  factory AlarmSong.fromJson(List<dynamic> json) {
    return AlarmSong(
      fileName: json[0] as String,
      hour: json[1] as int,
      minute: json[2] as int,
      startTimestamp: json[3] as int,
      endTimestamp: json[4] as int,
      status: json[5] as int,
      days: json[6] as int,
    );
  }

  // Check if the song is scheduled for a specific day
  bool isScheduledForDay(DateTime day) {
    final weekday = day.weekday; // 1 = Monday, 7 = Sunday
    int bitPosition;
    if (weekday == 7) {
      bitPosition = 7; // Sunday = bit 7
    } else {
      bitPosition = weekday; // Monday (1) = bit 1, Tuesday (2) = bit 2, etc.
    }
    final dayBit = 1 << bitPosition;
    final dayMatches = (days & dayBit) != 0;

    bool inRange = true;
    if (startTimestamp != 0 || endTimestamp != 0) {
      DateTime? startDT;
      if (startTimestamp != 0) {
        startDT = DateTime.fromMillisecondsSinceEpoch(startTimestamp * 1000);
      }
      DateTime? endDT;
      if (endTimestamp != 0) {
        endDT = DateTime.fromMillisecondsSinceEpoch(endTimestamp * 1000);
      } else if (startDT != null) {
        endDT = startDT;
      } else {
        inRange = false;
      }
      if (inRange) {
        final dayDate = DateTime(day.year, day.month, day.day);
        final startDate = DateTime(startDT!.year, startDT.month, startDT.day);
        final endDate = DateTime(endDT!.year, endDT.month, endDT.day);
        inRange = !dayDate.isBefore(startDate) && !dayDate.isAfter(endDate);
      }
    }
    final isScheduled = inRange && dayMatches;
    debugPrint(
        'Song: $fileName, Time: $hour:$minute, Days: $days (binary: ${days.toRadixString(2)}), '
            'Weekday: $weekday, BitPosition: $bitPosition, DayBit: $dayBit, '
            'Scheduled: $isScheduled');
    return isScheduled;
  }

  // Get the time string for display
  String getTimeString(BuildContext context) {
    // Always use hour and minute for consistency
    return TimeOfDay(hour: hour, minute: minute).format(context);
  }

  // Check if the song is in the past for a specific day
  bool isPast(DateTime day, DateTime now) {
    final songDateTime = DateTime(day.year, day.month, day.day, hour, minute);
    return songDateTime.isBefore(now);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<String> _namazTimes = [];
  List<String> _poojaTimes = [];
  late TabLogic _tabLogic;
  late TabLogic1 _musicTabLogic;
  late CalendarLogic _calendarLogic;
  bool _isFabMenuOpen = false;
  List<AlarmSong> _alarmSongs = [];
  bool _loadingAlarmSongs = false;
  bool _errorLoadingAlarmSongs = false;
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
  DateTime? _lastSnackTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabLogic = TabLogic();
    _musicTabLogic = TabLogic1();
    _calendarLogic = CalendarLogic();
    _initializeApp();
    _requestPermissions();
    _startWifiMonitoring();
    _loadPrayerTimesStatus();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadPrayerTimesStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pauseTimers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _lastSnackTime = null; // Reset snackbar throttle on resume to allow fresh popup if needed
      _pauseTimers();
      _startWifiMonitoring();
      // Delay the load to allow network to settle
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _loadPrayerTimesStatus();
        }
      });
      _restartPrayerTimer();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pauseTimers();
    }
  }

  void _pauseTimers() {
    wifiCheckTimer?.cancel();
    wifiCheckTimer = null;
    _timer?.cancel();
    _timer = null;
  }

  void _restartPrayerTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadPrayerTimesStatus();
    });
  }

  Future<void> _initializeApp() async {
    // Start Wi-Fi monitoring first
    await _startWifiMonitoring();

    // Small delay to ensure Wi-Fi status is updated
    await Future.delayed(const Duration(milliseconds: 3000));

    // Now load the prayer times status
    await _loadPrayerTimesStatus();

    // Start the periodic timer for updates
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadPrayerTimesStatus();
    });
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
        title: Text("Location Service Required", style: AppTextStyles.heading),
        content: Text(
          "E-Bell needs location services to detect Wi-Fi networks. "
              "Please enable location services in your device settings.",
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

  String _previousConnectionStatus = "";
  String _previousWifiSSID = "";

  Future<void> _checkWifiConnection() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        String? wifiSSID = await NetworkInfo().getWifiName();
        String? cleanedSSID = wifiSSID?.replaceAll('"', '').trim();
        debugPrint("Raw Wi-Fi SSID: $wifiSSID");
        debugPrint("Cleaned Wi-Fi SSID: $cleanedSSID");

        bool isTargetWifi = cleanedSSID != null &&
            cleanedSSID.toLowerCase() == targetSsid.toLowerCase();

        setState(() {
          isWifiConnected = true;
          if (isTargetWifi) {
            connectionStatus = "Connected to $targetSsid";
          } else {
            connectionStatus = "Connected to Wi-Fi: ${cleanedSSID ?? 'Unknown'}";
          }
        });

        // Only trigger API call if we just connected to target Wi-Fi
        bool justConnectedToTarget = isTargetWifi &&
            (_previousWifiSSID != cleanedSSID ||
                !_previousConnectionStatus.contains(targetSsid));

        if (isTargetWifi && justConnectedToTarget && mounted) {
          debugPrint("Newly connected to target Wi-Fi, loading data...");
          _loadPrayerTimesStatus();
        }

        // Update previous values
        _previousWifiSSID = cleanedSSID ?? "";
        _previousConnectionStatus = connectionStatus;

      } else {
        setState(() {
          isWifiConnected = false;
          connectionStatus = "Not connected to Wi-Fi";
        });

        // Reset previous values when disconnecting
        _previousWifiSSID = "";
        _previousConnectionStatus = "";
      }
    } catch (e) {
      setState(() {
        isWifiConnected = false;
        connectionStatus = "Error checking Wi-Fi: $e";
      });
      debugPrint("Error checking Wi-Fi: $e");
    }
  }

  Future<Map<String, dynamic>> _checkPrayerTimesStatus() async {
    http.Client? client;
    try {
      client = http.Client();
      final response = await client.get(
        Uri.parse('http://192.168.2.1/regtime'),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('regtime API timed out');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('regtime API HTTP ${response.statusCode}');
      }

      final jsonData = jsonDecode(response.body);

      final namazList = (jsonData['NAMAZ'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      final poojaList = (jsonData['POOJA'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      debugPrint('regtime → NAMAZ: $namazList, POOJA: $poojaList');

      return {
        'namazTimes': namazList,
        'poojaTimes': poojaList,
      };
    } catch (e) {
      debugPrint('Error checking regtime: $e');
      throw Exception('Failed to check regtime status: $e');
    } finally {
      client?.close();
    }
  }

  Future<Map<String, dynamic>> _fetchRegionStatus() async {
    http.Client? client;
    try {
      client = http.Client();
      final response = await client.get(
        Uri.parse('http://192.168.2.1/'),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Root API timed out'),
      );

      if (response.statusCode != 200) {
        throw Exception('Root API HTTP ${response.statusCode}');
      }

      final jsonData = jsonDecode(response.body);

      final regionList = (jsonData['region'] as List<dynamic>? ?? []);
      int poojaFlag = 0;
      int namazFlag = 0;
      for (var item in regionList) {
        if (item is Map) {
          if (item.containsKey('POOJA')) poojaFlag = item['POOJA'] ?? 0;
          if (item.containsKey('NAMAZ')) namazFlag = item['NAMAZ'] ?? 0;
        }
      }

      final alarmDataList = jsonData['alarmData'] as List<dynamic>? ?? [];
      List<AlarmSong> alarmSongs = [];
      if (alarmDataList.isNotEmpty) {
        final files = alarmDataList[0]['Filenames'] as List<dynamic>? ?? [];
        alarmSongs = files
            .where((file) {
          if (file.length < 7) return false;
          final h = file[1];
          final m = file[2];
          return h is int && m is int && h >= 0 && h <= 23 && m >= 0 && m <= 59;
        })
            .map((file) => AlarmSong.fromJson(file))
            .toList();
      }

      debugPrint('Fetched alarm songs: ${alarmSongs.map((s) => "${s.fileName} @ ${s.hour}:${s.minute}, days: ${s.days}, start: ${s.startTimestamp}").toList()}');

      return {
        'namazEnabled': namazFlag == 1,
        'sunriseEnabled': poojaFlag == 1,
        'alarmSongs': alarmSongs,
      };
    } catch (e) {
      debugPrint("Error fetching region status and alarm songs: $e");
      throw Exception("Failed to fetch region status and alarm songs: $e");
    } finally {
      client?.close();
    }
  }

  Future<void> _loadPrayerTimesStatus() async {
    if (!mounted) return;
    if (!isWifiConnected || !connectionStatus.contains(targetSsid)) {
      final now = DateTime.now();
      if (_lastSnackTime == null || now.difference(_lastSnackTime!).inSeconds > 30) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please connect to IoGen_Speaker Wi-Fi to fetch data',
              style: AppTextStyles.body,
            ),
          ),
        );
        _lastSnackTime = now;
      }
      setState(() {
        _loadingPrayerStatus = false;
        _errorLoadingStatus = true;
        _loadingAlarmSongs = false;
        _errorLoadingAlarmSongs = true;
      });
      return;
    }

    setState(() {
      _loadingPrayerStatus = true;
      _errorLoadingStatus = false;
      _loadingAlarmSongs = true;
      _errorLoadingAlarmSongs = false;
    });

    try {
      final regionStatus = await _fetchRegionStatus();
      final regtimeData = await _checkPrayerTimesStatus();

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString(), style: AppTextStyles.body)),
      );
    }
  }

  Future<void> _deleteAlarm(AlarmSong alarm) async {
    if (!isWifiConnected || !connectionStatus.contains(targetSsid)) {
      final now = DateTime.now();
      if (_lastSnackTime == null || now.difference(_lastSnackTime!).inSeconds > 30) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Please connect to IoGen_Speaker Wi-Fi to delete alarm",
              style: AppTextStyles.body,
            ),
          ),
        );
        _lastSnackTime = now;
      }
      return;
    }

    try {
      final client = http.Client();

      // NEW API FORMAT: "filename,hour,min,s_epoch,e_epoch,weeks"
      // id parameter is no longer needed in the payload
      final requestData = "${alarm.fileName},${alarm.hour},${alarm.minute},${alarm.startTimestamp},${alarm.endTimestamp},${alarm.days}";

      debugPrint("Sending delete request: $requestData");

      final response = await client.post(
        Uri.parse('http://192.168.2.1/delete/'),
        headers: {'Content-Type': 'text/plain'},
        body: requestData,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Delete alarm API timed out'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _alarmSongs.remove(alarm);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Alarm deleted successfully",
              style: AppTextStyles.body,
            ),
          ),
        );
        await _loadPrayerTimesStatus(); // Refresh the alarm list
      } else {
        throw Exception('Delete alarm API HTTP ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to delete alarm: $e",
            style: AppTextStyles.body,
          ),
        ),
      );
    }
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
                await _deleteAlarm(alarm); // Fixed: pass the actual alarm object
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

  Widget _buildPrayerTimeIndicator(BuildContext context, {
    required String label,
    required bool enabled,
    List<String> times = const [],
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 8),
      constraints: const BoxConstraints(minWidth: 80),
      decoration: BoxDecoration(
        color: enabled ? themeProvider.selectedColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? themeProvider.selectedColor : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.circle,
            color: enabled ? themeProvider.selectedColor : Colors.grey,
            size: 14,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.small.copyWith(
                    color: enabled ? themeProvider.selectedColor : Colors.grey,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (enabled && times.isNotEmpty)
                  ...times.map((t) => Text(
                    t,
                    style: AppTextStyles.small.copyWith(
                      color: Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )),
              ],
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
                style: AppTextStyles.body.copyWith(fontSize: 14, color: Colors.red),
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
            _buildPrayerTimeIndicator(context,
              label: 'Alarms',
              enabled: true,
            ),
            _buildPrayerTimeIndicator(context,
              label: 'Reminders',
              enabled: true,
            ),
            _buildPrayerTimeIndicator(context,
              label: 'Namaz',
              enabled: _namazEnabled,
            ),
            _buildPrayerTimeIndicator(context,
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
        final now = DateTime.now();
        if (_lastSnackTime == null || now.difference(_lastSnackTime!).inSeconds > 30) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Please connect to IoGen_Speaker Wi-Fi to sync time",
                style: AppTextStyles.body,
              ),
            ),
          );
          _lastSnackTime = now;
        }
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
              style: AppTextStyles.body,
            ),
          ),
        );
      }
      try {
        await BellService().syncTime(context, selectedTime: selectedDateTime);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Time synced successfully: ${selectedTime.format(context)}",
              style: AppTextStyles.body,
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to sync time: $e",
              style: AppTextStyles.body,
            ),
          ),
        );
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
              break;
            case 'Reminder':
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReminderPage()),
              );
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
                children: [
                  Text(
                    'Regional',
                    style: AppTextStyles.body.copyWith(color: Colors.black87),
                  ),
                  Text(
                    'Planner',
                    style: AppTextStyles.body.copyWith(color: Colors.black87),
                  ),
                ],
              )
                  : Text(
                title,
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int hour, int minute) {
    return DateFormat.jm().format(DateTime(2000, 1, 1, hour, minute));
  }

  Widget _buildDaysRow(int days, Color selectedColor) {
    final List<String> abbr = ['M', 'T', 'W', 'T', 'F', 'S', 'S']; // Mon Tue Wed Thu Fri Sat Sun
    final List<int> bits = [1, 2, 3, 4, 5, 6, 7]; // bit1=Mon, ..., bit7=Sun
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // Changed from start to center
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
                      onPageChanged: _onPageChanged,
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
                          _buildStatusIndicators(),
                          Text(
                            isSameDay(selectedDay, today)
                                ? "Today's Schedule"
                                : DateFormat('MMMM d, y').format(selectedDay),
                            style: AppTextStyles.subheading,
                          ),
                          const SizedBox(height: 12),
                          if (_loadingAlarmSongs) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                          ],
                          if (_errorLoadingAlarmSongs) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Failed to load alarm songs',
                                      style: AppTextStyles.body.copyWith(fontSize: 14, color: Colors.red),
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
                            ),
                          ],
                          if (!_loadingAlarmSongs && !_errorLoadingAlarmSongs) ...[
                            Builder(builder: (context) {
                              final alarmList = _alarmSongs
                                  .where((s) => s.isScheduledForDay(selectedDay) && s.startTimestamp == 0)
                                  .toList();
                              final reminderList = _alarmSongs
                                  .where((s) => s.isScheduledForDay(selectedDay) && s.startTimestamp != 0)
                                  .toList();

                              debugPrint(
                                  'Reminders for ${DateFormat('yyyy-MM-dd').format(selectedDay)}: ${reminderList.map((s) => "${s.fileName} @ ${s.hour}:${s.minute}, start: ${s.startTimestamp}, end: ${s.endTimestamp}").join(', ')}');

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (alarmList.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
                                      child: Text(
                                        'Alarms',
                                        style: AppTextStyles.subheading.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    ...alarmList.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final song = entry.value;
                                      final timeString = _formatTime(song.hour, song.minute);
                                      final isChecked = song.status == 1 && song.isPast(selectedDay, DateTime.now());
                                      final isLast = index == alarmList.length - 1;

                                      return GestureDetector(
                                        onLongPress: () => _showAlarmDetailsDialog(song),
                                        child: ScheduleItem(
                                          time: timeString,
                                          title: '', // Empty title
                                          isChecked: isChecked,
                                          isLast: isLast,
                                          icon: Icons.alarm,
                                          days: song.days,
                                          selectedColor: themeProvider.selectedColor,
                                        ),
                                      );
                                    }),
                                  ],
                                  if (reminderList.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
                                      child: Text(
                                        'Reminders',
                                        style: AppTextStyles.subheading.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    ...reminderList.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final song = entry.value;
                                      final timeString = _formatTime(song.hour, song.minute);
                                      final isChecked = song.status == 1 && song.isPast(selectedDay, DateTime.now());
                                      final isLast = index == reminderList.length - 1;

                                      return ScheduleItem(
                                        time: timeString,
                                        title: '', // Empty title
                                        isChecked: isChecked,
                                        isLast: isLast,
                                        icon: Icons.notifications_outlined,
                                        days: song.days,
                                        selectedColor: themeProvider.selectedColor,
                                      );
                                    }),
                                  ],
                                  if (_namazEnabled && _namazTimes.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
                                      child: Text(
                                        'Namaz',
                                        style: AppTextStyles.subheading.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    ..._namazTimes.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final t = entry.value;
                                      String fileName = 'Namaz'; // Default name
                                      String timeStr = t;

                                      // Extract file name from the time string
                                      if (t.contains(': ')) {
                                        final parts = t.split(': ');
                                        if (parts.length >= 2) {
                                          fileName = parts[0]; // This will be the actual file name from device
                                          timeStr = parts[1];
                                        }
                                      }

                                      int hour = 0;
                                      int minute = 0;
                                      try {
                                        final timeParts = timeStr.split(':');
                                        hour = int.parse(timeParts[0]);
                                        minute = int.parse(timeParts[1]);
                                      } catch (e) {
                                        // Invalid time, skip or handle
                                        return const SizedBox.shrink();
                                      }
                                      final timeString = _formatTime(hour, minute);
                                      final songDateTime = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, hour, minute);
                                      final isChecked = songDateTime.isBefore(DateTime.now());
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: ScheduleItem(
                                          time: timeString,
                                          title: fileName, // Use the actual file name from device
                                          isChecked: isChecked,
                                          isLast: index == _namazTimes.length - 1,
                                          icon: Icons.mosque_outlined,
                                        ),
                                      );
                                    }),
                                  ],
                                  if (_sunriseEnabled && _poojaTimes.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
                                      child: Text(
                                        'Sunrise/Sunset',
                                        style: AppTextStyles.subheading.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    ..._poojaTimes.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final t = entry.value;
                                      String fileName = 'Pooja'; // Default name
                                      String timeStr = t;

                                      // Extract file name from the time string
                                      if (t.contains(': ')) {
                                        final parts = t.split(': ');
                                        if (parts.length >= 2) {
                                          fileName = parts[0]; // This will be the actual file name from device
                                          timeStr = parts[1];
                                        }
                                      }

                                      int hour = 0;
                                      int minute = 0;
                                      try {
                                        final timeParts = timeStr.split(':');
                                        hour = int.parse(timeParts[0]);
                                        minute = int.parse(timeParts[1]);
                                      } catch (e) {
                                        // Invalid time, skip or handle
                                        return const SizedBox.shrink();
                                      }
                                      final timeString = _formatTime(hour, minute);
                                      final songDateTime = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, hour, minute);
                                      final isChecked = songDateTime.isBefore(DateTime.now());
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: ScheduleItem(
                                          time: timeString,
                                          title: fileName, // Use the actual file name from device
                                          isChecked: isChecked,
                                          isLast: index == _poojaTimes.length - 1,
                                          icon: Icons.wb_sunny,
                                        ),
                                      );
                                    }),
                                  ],
                                  if (alarmList.isEmpty && reminderList.isEmpty && (!_namazEnabled || _namazTimes.isEmpty) && (!_sunriseEnabled || _poojaTimes.isEmpty))
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        'No alarms or reminders scheduled for this day',
                                        style: AppTextStyles.body.copyWith(color: Colors.grey),
                                      ),
                                    ),
                                ],
                              );
                            }),
                          ],
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
          // Wrap your main content with GestureDetector to detect outside taps
          GestureDetector(
            onTap: () {
              if (_isFabMenuOpen) {
                setState(() {
                  _isFabMenuOpen = false;
                });
              }
            },
            child: screens[_selectedIndex],
          ),

          if (_isFabMenuOpen && _selectedIndex == 0)
            Positioned(
              bottom: 80,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  // This prevents the menu from closing when clicking inside it
                },
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
            ),
        ],
      ),
      // Replace your current FAB in HomeScreen with this:
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
        onPressed: () {
          setState(() {
            _isFabMenuOpen = !_isFabMenuOpen;
          });
        },
        backgroundColor: themeProvider.selectedColor,
        shape: const CircleBorder(), // Ensure it's circular
        child: Icon(
          _isFabMenuOpen ? Icons.close : Icons.edit_calendar_outlined,
          color: Colors.white, // White icon for better contrast
          size: 28, // Consistent size
        ),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      bottomNavigationBar: SizedBox(
        height: 75,
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onNavBarTapped,
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 0,
          unselectedFontSize: 0,
          items: [
            BottomNavigationBarItem(
              icon: _buildNavItem(
                isSelected: _selectedIndex == 0,
                selectedIcon: Icons.calendar_month,
                unselectedIcon: Icons.calendar_month_outlined,
                label: "Planner",
                color: themeProvider.selectedColor,
              ),
              label: "",
            ),
            BottomNavigationBarItem(
              icon: _buildNavItem(
                isSelected: _selectedIndex == 1,
                selectedIcon: Icons.music_note,
                unselectedIcon: Icons.music_note_outlined,
                label: "Library",
                color: themeProvider.selectedColor,
              ),
              label: "",
            ),
            BottomNavigationBarItem(
              icon: _buildNavItem(
                isSelected: _selectedIndex == 2,
                selectedIcon: Icons.person,
                unselectedIcon: Icons.person_outline,
                label: "Profile",
                color: themeProvider.selectedColor,
              ),
              label: "",
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildNavItem({
  required bool isSelected,
  required IconData selectedIcon,
  required IconData unselectedIcon,
  required String label,
  required Color color,
}) {
  return SizedBox(
    height: 60,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isSelected ? selectedIcon : unselectedIcon,
          color: isSelected ? color : Colors.grey,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.small.copyWith(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? color : Colors.grey,
          ),
        ),
        const Spacer(),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        ),
      ],
    ),
  );
}