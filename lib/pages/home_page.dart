import 'package:flutter/cupertino.dart';
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
import '../services/user_preferences_service.dart';
import '../utils/app_text_styles.dart';

class AlarmSong {
  final String fileName;
  final int hour;
  final int minute;
  final int startTimestamp;
  final int endTimestamp;
  final int status;
  final int days;
  final int uniqueId;

  AlarmSong({
    required this.fileName,
    required this.hour,
    required this.minute,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.status,
    required this.days,
    required this.uniqueId,
  });

  factory AlarmSong.fromJson(List<dynamic> json) {
    return AlarmSong(
      uniqueId: json[0] as int,
      // ← THIS IS THE REAL UNIQUE CODE FROM ESP32
      fileName: json[1] as String,
      hour: json[2] as int,
      minute: json[3] as int,
      startTimestamp: json[4] as int,
      endTimestamp: json[5] as int,
      status: json[6] as int,
      days: json[7] as int,
    );
  }

  bool isScheduledForDay(DateTime day) {
    final weekday = day.weekday;
    int bitPosition = weekday == 7 ? 7 : weekday;
    final dayBit = 1 << bitPosition;
    final dayMatches = (days & dayBit) != 0;

    bool inRange = true;
    if (startTimestamp != 0 || endTimestamp != 0) {
      DateTime? startDT = startTimestamp != 0
          ? DateTime.fromMillisecondsSinceEpoch(startTimestamp * 1000)
          : null;
      DateTime? endDT = endTimestamp != 0
          ? DateTime.fromMillisecondsSinceEpoch(endTimestamp * 1000)
          : startDT;

      if (startDT == null || endDT == null) {
        inRange = false;
      } else {
        final dayDate = DateTime(day.year, day.month, day.day);
        final startDate = DateTime(startDT.year, startDT.month, startDT.day);
        final endDate = DateTime(endDT.year, endDT.month, endDT.day);
        inRange = !dayDate.isBefore(startDate) && !dayDate.isAfter(endDate);
      }
    }
    return inRange && dayMatches;
  }

  String getTimeString(BuildContext context) {
    return TimeOfDay(hour: hour, minute: minute).format(context);
  }

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
  List<String> _jainTimes = []; // Added for Jain
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
  bool _namazEnabled = false;
  bool _sunriseEnabled = false;
  bool _jainEnabled = false; // Added for Jain
  bool _loadingPrayerStatus = false;
  bool _errorLoadingStatus = false;
  final GlobalKey _calendarKey = GlobalKey();
  bool _isScrolling = false;
  final ScrollController _scrollController = ScrollController();
  String? _lastShownSnackBarMessage;
  bool _autoRefreshEnabled = false;
  bool _wasPreviouslyOffscreen = true;
  OverlayEntry? _fabMenuOverlayEntry;
  bool _initialLoadDone = false;
  DateTime? _lastBackPressed;String get _targetSsid {
    final userPrefs = Provider.of<UserPreferencesService>(context, listen: false);
    return userPrefs.userSsid ?? 'NO FallBack'; // Fallback if not set
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabLogic = TabLogic();
    _musicTabLogic = TabLogic1();
    _calendarLogic = CalendarLogic();

    _wasPreviouslyOffscreen = true;

    _scrollController.addListener(() {
      final position = _scrollController.position;
      setState(() {
        _isScrolling = position.isScrollingNotifier.value;
      });
    });

    _initializeApp();
    _requestPermissions();

    _startWifiMonitoring();
  }

  @override
  void dispose() {
    _hideFabMenuOverlay();
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    wifiCheckTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute? route = ModalRoute.of(context);
    if (route is PageRoute) {
      if (route.isCurrent && _wasPreviouslyOffscreen) {
        _wasPreviouslyOffscreen = false;
        if (isWifiConnected && connectionStatus.contains(_targetSsid)) {
          _loadPrayerTimesStatus();
        }
      } else if (!route.isCurrent) {
        _wasPreviouslyOffscreen = true;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      wifiCheckTimer?.cancel();
      _timer?.cancel();
      debugPrint("Timers paused (app in background)");
    } else if (state == AppLifecycleState.resumed) {
      _startWifiMonitoring();
      debugPrint("Wi-Fi monitoring resumed");
    }
  }

  Future<void> _initializeApp() async {
    await _startWifiMonitoring();

    // if (mounted) _loadPrayerTimesStatus();
  }

  Future<bool> _onWillPop() async {
    // Case 1: Profile or Music → go Home
    if (_selectedIndex == 2 || _selectedIndex == 1) {
      setState(() => _selectedIndex = 0);
      return false; // block system back
    }

    // Case 2: Already on Home → double back to exit
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Press back again to exit"),
          duration: Duration(seconds: 2),
        ),
      );

      return false; // don’t exit yet
    }

    return true; // exit app
  }

  Future<void> _requestPermissions() async {
    Location location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        _updateConnectionStatus("Location service is disabled");
        _showLocationServiceDialog();
        return;
      }
    }

    var status = await Permission.location.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      _updateConnectionStatus("Location permission denied");
      _showPermissionDialog();
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
            child: Text("Cancel",
                style: AppTextStyles.button.copyWith(color: Colors.black)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: Text("Open Settings",
                style: AppTextStyles.button.copyWith(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showFabMenuOverlay() {
    if (_fabMenuOverlayEntry != null) return;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    _fabMenuOverlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideFabMenuOverlay,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            bottom: 165,
            right: 16,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFabOption('Reminder', true),
                    _buildFabOption('Alarm', false),
                    _buildFabOption('Astro', false),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_fabMenuOverlayEntry!);
  }

  void _hideFabMenuOverlay() {
    _fabMenuOverlayEntry?.remove();
    _fabMenuOverlayEntry = null;
    if (mounted) {
      setState(() => _isFabMenuOpen = false);
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text("Location Permission Required", style: AppTextStyles.heading),
        content: Text(
          "E-Bell needs location permission to sync with the bell. "
          "Please grant this permission in app settings.",
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel",
                style: AppTextStyles.button.copyWith(color: Colors.black)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: Text("Open Settings",
                style: AppTextStyles.button.copyWith(color: Colors.black)),
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

  String _previousWifiSSID = "";
  String _previousConnectionStatus = "";

  void _updateConnectionStatus(String status) {
    if (mounted) {
      setState(() {
        connectionStatus = status;
      });
    }
  }

  // Change from DateTime.now() to a past time
  DateTime _lastWifiCheck = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _checkWifiConnection() async {
    // 1. Remove the time check throttling for the very first run, or keep it low
    // if (DateTime.now().difference(_lastWifiCheck) < const Duration(seconds: 2)) {
    //   return;
    // }

    try {
      var connectivityResult = await Connectivity().checkConnectivity();

      // Check if we are connected to ANY Wi-Fi
      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        String? wifiSSID = await NetworkInfo().getWifiName();
        String? cleanedSSID = wifiSSID?.replaceAll('"', '').trim();
        String normalizedSSID = cleanedSSID?.toLowerCase() ?? '';

        // Check if it is the SPECIFIC Target Wi-Fi
        bool isTargetWifi = normalizedSSID == _targetSsid.toLowerCase();

        String displaySSID = cleanedSSID ?? 'Unknown';
        String newStatus = isTargetWifi
            ? "Connected to $_targetSsid"
            : "Connected to Wi-Fi: $displaySSID";

        if (mounted) {
          setState(() {
            isWifiConnected = true;
            connectionStatus = newStatus;
          });

          // === CRITICAL FIX START ===
          // If we found the target Wifi, and we haven't done the initial load yet:
          if (isTargetWifi && !_initialLoadDone) {
            debugPrint(
                "⚡ Fresh Start: Target Wi-Fi detected -> Fetching Data Now");

            // 1. Set the flag immediately to prevent double-fetching
            _initialLoadDone = true;

            // 2. Call the load function
            _loadPrayerTimesStatus();
          }
          // === CRITICAL FIX END ===
        }

        _previousWifiSSID = cleanedSSID ?? "";
        _previousConnectionStatus = newStatus;
      } else {
        // ... (Existing else block for no wifi) ...
        if (mounted) {
          setState(() {
            isWifiConnected = false;
            connectionStatus = "Not connected to Wi-Fi";
            // Reset the flag if we lose connection, so it auto-fetches again on reconnect
            _initialLoadDone = false;
          });
        }
      }
      _lastWifiCheck = DateTime.now();
    } catch (e) {
      // ... error handling ...
    }
  }

  Future<Map<String, dynamic>> _checkPrayerTimesStatus() async {
    http.Client? client;
    try {
      client = http.Client();
      final response = await client
          .get(Uri.parse('http://192.168.2.1/regtime'))
          .timeout(const Duration(seconds: 5),
              onTimeout: () => throw Exception('regtime timeout'));

      if (response.statusCode != 200)
        throw Exception('regtime HTTP ${response.statusCode}');
      final jsonData = jsonDecode(response.body);

      return {
        'namazTimes': (jsonData['NAMAZ'] as List?)?.cast<String>() ?? [],
        'poojaTimes': (jsonData['POOJA'] as List?)?.cast<String>() ?? [],
        'jainTimes': (jsonData['JAIN'] as List?)?.cast<String>() ?? [],
        // Fetch Jain times
      };
    } finally {
      client?.close();
    }
  }

  Future<Map<String, dynamic>> _fetchRegionStatus() async {
    http.Client? client;
    try {
      client = http.Client();
      final response = await client
          .get(Uri.parse('http://192.168.2.1/'))
          .timeout(const Duration(seconds: 5), onTimeout: () {
        throw Exception('Root endpoint timeout');
      });

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final jsonData = jsonDecode(response.body);

      // === Parse region flags (NAMAZ, POOJA, JAIN, etc.) ===
      int namazFlag = 0;
      int poojaFlag = 0;
      int jainFlag = 0; // Added Jain Flag

      final regionList = jsonData['region'] as List?;
      if (regionList != null) {
        for (var item in regionList) {
          if (item is Map<String, dynamic>) {
            namazFlag = item['NAMAZ'] ?? namazFlag;
            poojaFlag = item['POOJA'] ?? poojaFlag;
            jainFlag = item['JAIN'] ?? jainFlag; // Check Jain status
          }
        }
      }

      // === Parse alarm songs (new format with leading ID) ===
      List<AlarmSong> alarmSongs = [];

      final alarmDataList = jsonData['alarmData'] as List?;
      if (alarmDataList != null && alarmDataList.isNotEmpty) {
        final filenamesList = alarmDataList[0]['Filenames'] as List?;

        if (filenamesList != null) {
          for (var item in filenamesList) {
            if (item is List && item.length >= 8) {
              try {
                // New format: [id, filename, hour, minute, startTs, endTs, status, days]
                final String fileName = item[1] as String;
                final int hour = item[2] as int;
                final int minute = item[3] as int;
                final int startTimestamp = item[4] as int;
                final int endTimestamp = item[5] as int;
                final int status = item[6] as int;
                final int days = item[7] as int;

                alarmSongs.add(AlarmSong.fromJson(item));
              } catch (e) {
                debugPrint("Failed to parse alarm item: $item, error: $e");
              }
            }
          }
        }
      }

      return {
        'namazEnabled': namazFlag == 1,
        'sunriseEnabled': poojaFlag == 1,
        'jainEnabled': jainFlag == 1, // Return Jain status
        'alarmSongs': alarmSongs,
      };
    } catch (e) {
      debugPrint('Error fetching region status: $e');
      rethrow;
    } finally {
      client?.close();
    }
  }

  // Change from DateTime.now() to a past time so the first fetch isn't blocked
  DateTime _lastRefreshTime = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _refreshCooldown = Duration(seconds: 5);

  Future<void> _loadPrayerTimesStatus() async {
    if (DateTime.now().difference(_lastRefreshTime) < _refreshCooldown) {
      return;
    }

    if (!mounted) return;

    if (!isWifiConnected || !connectionStatus.contains(_targetSsid)) {
      setState(() {
        _loadingPrayerStatus = false;
        _errorLoadingStatus = true;
        _loadingAlarmSongs = false;
        _errorLoadingAlarmSongs = true;
      });

      const message = 'Please connect to IoGen_Speaker Wi-Fi to fetch data';
      if (_lastShownSnackBarMessage != message) {
        _lastShownSnackBarMessage = message;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message, style: AppTextStyles.body),
                duration: const Duration(seconds: 7),
              ),
            );
          }
        });
      }
      return;
    } else {
      _lastShownSnackBarMessage = null;
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
        _jainEnabled =
            regionStatus['jainEnabled'] ?? false; // Update Jain state
        _alarmSongs = (regionStatus['alarmSongs'] as List<AlarmSong>)
          ..sort((a, b) =>
              (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
        _namazTimes = regtimeData['namazTimes'];
        _poojaTimes = regtimeData['poojaTimes'];
        _jainTimes = regtimeData['jainTimes']; // Update Jain times
        _loadingPrayerStatus = false;
        _loadingAlarmSongs = false;
        _lastRefreshTime = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPrayerStatus = false;
        _errorLoadingStatus = true;
        _loadingAlarmSongs = false;
        _errorLoadingAlarmSongs = true;
        _lastRefreshTime = DateTime.now();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString(), style: AppTextStyles.body)),
          );
        }
      });
    }
  }

  Future<void> _deleteAlarm(AlarmSong alarm) async {
    if (!isWifiConnected || !connectionStatus.contains(_targetSsid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Please connect to IoGen_Speaker Wi-Fi to delete alarm")),
      );
      return;
    }

    try {
      final client = http.Client();
      final String requestData = ",${alarm.uniqueId}"; // Example: ",1"

      final response = await client
          .post(
            Uri.parse('http://192.168.2.1/delete/'),
            headers: {'Content-Type': 'text/plain'},
            body: requestData,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _alarmSongs.remove(alarm);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Alarm deleted successfully")),
        );
        _loadPrayerTimesStatus();
      } else {
        throw Exception('Server responded with ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete alarm: $e")),
      );
    }
  }

  void _showEditAlarmDialog(AlarmSong alarm) {
    final selectedColor =
        Provider.of<ThemeProvider>(context, listen: false).selectedColor;

    int selectedHour = alarm.hour;
    int selectedMinute = alarm.minute;

    String period = selectedHour < 12 ? "AM" : "PM";

    int hourOfPeriod = selectedHour % 12;
    if (hourOfPeriod == 0) hourOfPeriod = 12;

    final hourController =
        FixedExtentScrollController(initialItem: hourOfPeriod - 1);
    final minuteController =
        FixedExtentScrollController(initialItem: selectedMinute);
    final periodController =
        FixedExtentScrollController(initialItem: period == "AM" ? 0 : 1);

    Set<int> selectedDays = {};
    for (int i = 0; i < 7; i++) {
      if ((alarm.days & (1 << i)) != 0) selectedDays.add(i);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          int getWeekMask() {
            int mask = 0;
            for (int d in selectedDays) mask |= (1 << d);
            return mask == 0 ? 255 : mask;
          }

          // SMALL COMPACT WHEEL
          Widget buildWheel({
            required FixedExtentScrollController controller,
            required int count,
            required int selectedValue,
            required Function(int) onChanged,
            required String Function(int) format,
          }) {
            return SizedBox(
              width: 70,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // highlight
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(0),
                        ),
                      ),
                    ),
                  ),

                  ListWheelScrollView.useDelegate(
                    controller: controller,
                    itemExtent: 40,
                    perspective: 0.001,
                    diameterRatio: 1.4,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      onChanged(index);
                      setStateDialog(() {});
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: count,
                      builder: (context, index) {
                        int value = index % count;
                        bool isSelected = value == selectedValue;

                        return Center(
                          child: Text(
                            format(value),
                            style: TextStyle(
                              fontSize: isSelected ? 26 : 16,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? selectedColor
                                  : Colors.black.withOpacity(0.35),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }

          // SMALL COMPACT AM/PM wheel
          Widget buildPeriodWheel() {
            return SizedBox(
              width: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(0),
                        ),
                      ),
                    ),
                  ),
                  ListWheelScrollView.useDelegate(
                    controller: periodController,
                    itemExtent: 40,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      period = index == 0 ? "AM" : "PM";

                      if (period == "AM" && selectedHour >= 12) {
                        selectedHour -= 12;
                      } else if (period == "PM" && selectedHour < 12) {
                        selectedHour += 12;
                      }

                      setStateDialog(() {});
                    },
                    childDelegate: ListWheelChildListDelegate(
                      children: ["AM", "PM"].map((p) {
                        final isSel = p == period;
                        return Center(
                          child: Text(
                            p,
                            style: TextStyle(
                              fontSize: isSel ? 26 : 16,
                              fontWeight: FontWeight.w600,
                              color: isSel
                                  ? selectedColor
                                  : Colors.black.withOpacity(0.35),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            title: const Center(
              child: Text(
                "Edit Alarm",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 180,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // HOUR wheel
                      buildWheel(
                        controller: hourController,
                        count: 12,
                        selectedValue: hourOfPeriod - 1,
                        // FIXED alignment
                        format: (v) => (v + 1).toString().padLeft(2, '0'),
                        onChanged: (index) {
                          int hour12 = index + 1;
                          hourOfPeriod = hour12;

                          selectedHour = period == "AM"
                              ? (hour12 == 12 ? 0 : hour12)
                              : (hour12 == 12 ? 12 : hour12 + 12);
                        },
                      ),

                      // MINUTE wheel
                      buildWheel(
                        controller: minuteController,
                        count: 60,
                        selectedValue: selectedMinute,
                        format: (v) => v.toString().padLeft(2, '0'),
                        onChanged: (index) => selectedMinute = index % 60,
                      ),

                      // AM / PM
                      buildPeriodWheel(),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (selectedDays.isEmpty)
                  const Text(
                    "Select at least one day",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.redAccent,
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(7, (i) {
                    final labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                    final sel = selectedDays.contains(i);

                    return GestureDetector(
                      onTap: () {
                        setStateDialog(() {
                          sel ? selectedDays.remove(i) : selectedDays.add(i);
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sel ? selectedColor : Colors.white,
                          border: Border.all(
                            color: sel ? selectedColor : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.only(top: 6, bottom: 20),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: 120,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side:
                            BorderSide(color: Colors.grey.shade400, width: 1.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: selectedDays.isEmpty
                          ? null
                          : () async {
                              if (!isWifiConnected ||
                                  !connectionStatus.contains(_targetSsid)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Connect to IoGen_Speaker Wi-Fi")),
                                );
                                return;
                              }

                              final weekMask = getWeekMask();

                              final body =
                                  "$selectedHour,$selectedMinute,0,0,1,$weekMask,1,${alarm.uniqueId}";

                              try {
                                final res = await http
                                    .post(
                                      Uri.parse(
                                          'http://192.168.2.1/update/${alarm.fileName}'),
                                      headers: {'Content-Type': 'text/plain'},
                                      body: body,
                                    )
                                    .timeout(const Duration(seconds: 5));

                                if (res.statusCode == 200 && mounted) {
                                  setState(() {
                                    final updated = AlarmSong(
                                      fileName: alarm.fileName,
                                      hour: selectedHour,
                                      minute: selectedMinute,
                                      startTimestamp: alarm.startTimestamp,
                                      endTimestamp: alarm.endTimestamp,
                                      status: alarm.status,
                                      days: weekMask,
                                      uniqueId: alarm.uniqueId,
                                    );

                                    final idx = _alarmSongs.indexWhere(
                                        (a) => a.uniqueId == alarm.uniqueId);

                                    if (idx != -1) {
                                      _alarmSongs[idx] = updated;
                                    }
                                  });

                                  // === FIX START: Force refresh data from device ===
                                  _lastRefreshTime = DateTime(0); // Bypass cooldown
                                  _loadPrayerTimesStatus();       // Fetch latest data
                                  // === FIX END ===

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text("Alarm updated successfully")),
                                  );

                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text("Update failed: $e")));
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: const Text(
                        "Save",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditReminderDialog(AlarmSong reminder) {
    final selectedColor =
        Provider.of<ThemeProvider>(context, listen: false).selectedColor;

    // ---- TIME ----
    int selectedHour = reminder.hour;
    int selectedMinute = reminder.minute;

    String period = selectedHour < 12 ? "AM" : "PM";

    int hourOfPeriod = selectedHour % 12;
    if (hourOfPeriod == 0) hourOfPeriod = 12;

    final hourController =
    FixedExtentScrollController(initialItem: hourOfPeriod - 1);
    final minuteController =
    FixedExtentScrollController(initialItem: selectedMinute);
    final periodController =
    FixedExtentScrollController(initialItem: period == "AM" ? 0 : 1);

    // ---- DATES (decode from stored epochs using same IST offset logic) ----
    const int IST_OFFSET = 5 * 3600 + 30 * 60;

    DateTime decodeEpochToLocal(int epoch) {
      // Stored as local - IST_OFFSET in _saveReminder
      final int localSeconds = epoch + IST_OFFSET;
      return DateTime.fromMillisecondsSinceEpoch(localSeconds * 1000);
    }

    final DateTime startLocal = reminder.startTimestamp > 0
        ? decodeEpochToLocal(reminder.startTimestamp)
        : DateTime.now();

    final DateTime endLocal = reminder.endTimestamp > 0
        ? decodeEpochToLocal(reminder.endTimestamp)
        : startLocal;

    DateTime selectedFromDate =
    DateTime(startLocal.year, startLocal.month, startLocal.day);
    DateTime selectedToDate =
    DateTime(endLocal.year, endLocal.month, endLocal.day);

    // ---- DAYS ---- (same style as _showEditAlarmDialog)
    Set<int> selectedDays = {};
    for (int i = 0; i < 7; i++) {
      if ((reminder.days & (1 << i)) != 0) selectedDays.add(i);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          int getWeekMask() {
            int mask = 0;
            for (int d in selectedDays) {
              mask |= (1 << d);
            }
            return mask == 0 ? 255 : mask; // fallback if none
          }

          Future<void> pickFromDate() async {
            final now = DateTime.now();
            final DateTime firstDate =
            DateTime(now.year, now.month, now.day); // no past
            final DateTime initial = selectedFromDate.isBefore(firstDate)
                ? firstDate
                : selectedFromDate;

            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: firstDate,
              lastDate: DateTime(2030, 12, 31),
            );

            if (picked != null) {
              setStateDialog(() {
                selectedFromDate =
                    DateTime(picked.year, picked.month, picked.day);
                if (selectedToDate.isBefore(selectedFromDate)) {
                  selectedToDate = selectedFromDate;
                }
              });
            }
          }

          Future<void> pickToDate() async {
            final now = DateTime.now();
            final DateTime firstDate =
            DateTime(now.year, now.month, now.day); // no past
            final DateTime initial = selectedToDate.isBefore(firstDate)
                ? firstDate
                : selectedToDate;

            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: firstDate,
              lastDate: DateTime(2030, 12, 31),
            );

            if (picked != null) {
              setStateDialog(() {
                selectedToDate = DateTime(picked.year, picked.month, picked.day);
                if (selectedFromDate.isAfter(selectedToDate)) {
                  selectedFromDate = selectedToDate;
                }
              });
            }
          }

          String formatDate(DateTime d) =>
              "${DateFormat('MMM d, yyyy').format(d)}";

          // --- Small wheel builder (same as alarm) ---
          Widget buildWheel({
            required FixedExtentScrollController controller,
            required int count,
            required int selectedValue,
            required Function(int) onChanged,
            required String Function(int) format,
          }) {
            return SizedBox(
              width: 70,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                        ),
                      ),
                    ),
                  ),
                  ListWheelScrollView.useDelegate(
                    controller: controller,
                    itemExtent: 40,
                    perspective: 0.001,
                    diameterRatio: 1.4,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      onChanged(index);
                      setStateDialog(() {});
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: count,
                      builder: (context, index) {
                        int value = index % count;
                        bool isSelected = value == selectedValue;
                        return Center(
                          child: Text(
                            format(value),
                            style: TextStyle(
                              fontSize: isSelected ? 26 : 16,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? selectedColor
                                  : Colors.black.withOpacity(0.35),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }

          Widget buildPeriodWheel() {
            return SizedBox(
              width: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                        ),
                      ),
                    ),
                  ),
                  ListWheelScrollView.useDelegate(
                    controller: periodController,
                    itemExtent: 40,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      period = index == 0 ? "AM" : "PM";

                      if (period == "AM" && selectedHour >= 12) {
                        selectedHour -= 12;
                      } else if (period == "PM" && selectedHour < 12) {
                        selectedHour += 12;
                      }

                      setStateDialog(() {});
                    },
                    childDelegate: ListWheelChildListDelegate(
                      children: ["AM", "PM"].map((p) {
                        final isSel = p == period;
                        return Center(
                          child: Text(
                            p,
                            style: TextStyle(
                              fontSize: isSel ? 26 : 16,
                              fontWeight: FontWeight.w600,
                              color: isSel
                                  ? selectedColor
                                  : Colors.black.withOpacity(0.35),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            title: Center(
              child: Column(
                children: [
                  const Text(
                    "Edit Reminder",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${formatDate(selectedFromDate)} → ${formatDate(selectedToDate)}",
                    style: AppTextStyles.small,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ---- FROM / TO date rows (like ReminderPage) ----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "From",
                        style: AppTextStyles.body.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: pickFromDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border:
                              Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatDate(selectedFromDate),
                                  style: AppTextStyles.body.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                                const Icon(Icons.calendar_today,
                                    size: 18, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "To",
                        style: AppTextStyles.body.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: pickToDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border:
                              Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatDate(selectedToDate),
                                  style: AppTextStyles.body.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                                const Icon(Icons.calendar_today,
                                    size: 18, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ---- TIME wheels ----
                  SizedBox(
                    height: 170,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildWheel(
                          controller: hourController,
                          count: 12,
                          selectedValue: hourOfPeriod - 1,
                          format: (v) => (v + 1).toString().padLeft(2, '0'),
                          onChanged: (index) {
                            int hour12 = index + 1;
                            hourOfPeriod = hour12;
                            selectedHour = period == "AM"
                                ? (hour12 == 12 ? 0 : hour12)
                                : (hour12 == 12 ? 12 : hour12 + 12);
                          },
                        ),
                        buildWheel(
                          controller: minuteController,
                          count: 60,
                          selectedValue: selectedMinute,
                          format: (v) => v.toString().padLeft(2, '0'),
                          onChanged: (index) {
                            selectedMinute = index % 60;
                          },
                        ),
                        buildPeriodWheel(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  if (selectedDays.isEmpty)
                    const Text(
                      "Select at least one day",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.redAccent,
                      ),
                    ),
                  const SizedBox(height: 8),

                  // ---- Days row (same as alarm dialog) ----
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(7, (i) {
                      final labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                      final sel = selectedDays.contains(i);

                      return GestureDetector(
                        onTap: () {
                          setStateDialog(() {
                            sel ? selectedDays.remove(i) : selectedDays.add(i);
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sel ? selectedColor : Colors.white,
                            border: Border.all(
                              color: sel
                                  ? selectedColor
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              labels[i],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? Colors.white
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.only(bottom: 20, top: 6),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: 120,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.grey.shade400, width: 1.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: selectedDays.isEmpty
                          ? null
                          : () async {
                        if (!isWifiConnected || !connectionStatus.contains(_targetSsid)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Connect to IoGen_Speaker Wi-Fi")),
                          );
                          return;
                        }

                        final int weekMask = getWeekMask();

                        // ---- recompute epochs exactly same as _saveReminder ----
                        final DateTime fromDateTime = DateTime(
                          selectedFromDate.year,
                          selectedFromDate.month,
                          selectedFromDate.day,
                          selectedHour,
                          selectedMinute,
                        );

                        final DateTime toDateTime = DateTime(
                          selectedToDate.year,
                          selectedToDate.month,
                          selectedToDate.day,
                          selectedHour,
                          selectedMinute,
                        );

                        const int IST_OFFSET = 5 * 3600 + 30 * 60;

                        int sEpoch = (fromDateTime.millisecondsSinceEpoch ~/ 1000) - IST_OFFSET;
                        int eEpoch =
                            (toDateTime.millisecondsSinceEpoch ~/ 1000) - IST_OFFSET + 86399;

                        // ---- final API body (same structure as alarm but alarmType = 2) ----
                        final String body =
                            "$selectedHour,$selectedMinute,$sEpoch,$eEpoch,1,$weekMask,2,${reminder.uniqueId}";

                        try {
                          final res = await http
                              .post(
                            Uri.parse("http://192.168.2.1/update/${reminder.fileName}"),
                            headers: {'Content-Type': 'text/plain'},
                            body: body,
                          )
                              .timeout(const Duration(seconds: 5));

                          if (res.statusCode == 200 && mounted) {
                            setState(() {
                              final updated = AlarmSong(
                                fileName: reminder.fileName,
                                hour: selectedHour,
                                minute: selectedMinute,
                                startTimestamp: sEpoch,
                                endTimestamp: eEpoch,
                                status: reminder.status,
                                days: weekMask,
                                uniqueId: reminder.uniqueId,
                              );

                              final idx = _alarmSongs.indexWhere(
                                      (a) => a.uniqueId == reminder.uniqueId);

                              if (idx != -1) {
                                _alarmSongs[idx] = updated;
                              }
                            });

                            // === FIX START: Force refresh data from device ===
                            _lastRefreshTime = DateTime(0); // Bypass cooldown
                            _loadPrayerTimesStatus();       // Fetch latest data
                            // === FIX END ===

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Reminder updated successfully")),
                            );

                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Update failed: ${res.statusCode}"),
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Update failed: $e"),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        disabledBackgroundColor:
                        Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: const Text(
                        "Save",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }



  void _showRemainderDetailsDialog(AlarmSong alarm) {
    final selectedColor =
        Provider.of<ThemeProvider>(context, listen: false).selectedColor;

    String rawTime =
        "${alarm.hour % 12 == 0 ? 12 : alarm.hour % 12}:${alarm.minute.toString().padLeft(2, '0')}";
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
              Text(rawTime, style: AppTextStyles.headingheading),
              const SizedBox(width: 4),
              Text(period,
                  style: AppTextStyles.heading
                      .copyWith(color: selectedColor, fontSize: 20)),
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
            Text(alarm.fileName,
                style: AppTextStyles.body, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Edit Button (Black)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close details dialog
                  _showEditReminderDialog(alarm); // Open edit dialog
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text("Edit",
                    style: AppTextStyles.button.copyWith(color: Colors.white)),
              ),
              const SizedBox(width: 16),
              // Delete Button (Red)
              ElevatedButton(
                onPressed: () async {
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text("Delete Alarm"),
                        content: const Text(
                            "Do you really want to delete this alarm?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("No"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Yes"),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirm == true) {
                    Navigator.pop(context); // Close bottom sheet
                    await _deleteAlarm(alarm); // Use your existing delete logic
                  }
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(
                  "Delete",
                  style: AppTextStyles.button.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }


  void _showAlarmDetailsDialog(AlarmSong alarm) {
    final selectedColor =
        Provider.of<ThemeProvider>(context, listen: false).selectedColor;

    String rawTime =
        "${alarm.hour % 12 == 0 ? 12 : alarm.hour % 12}:${alarm.minute.toString().padLeft(2, '0')}";
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
              Text(rawTime, style: AppTextStyles.headingheading),
              const SizedBox(width: 4),
              Text(period,
                  style: AppTextStyles.heading
                      .copyWith(color: selectedColor, fontSize: 20)),
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
            Text(alarm.fileName,
                style: AppTextStyles.body, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Edit Button (Black)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close details dialog
                  _showEditAlarmDialog(alarm); // Open edit dialog
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text("Edit",
                    style: AppTextStyles.button.copyWith(color: Colors.white)),
              ),
              const SizedBox(width: 16),
              // Delete Button (Red)
              ElevatedButton(
                onPressed: () async {
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text("Delete Alarm"),
                        content: const Text(
                            "Do you really want to delete this alarm?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("No"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Yes"),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirm == true) {
                    Navigator.pop(context); // Close bottom sheet
                    await _deleteAlarm(alarm); // Use your existing delete logic
                  }
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(
                  "Delete",
                  style: AppTextStyles.button.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPrayerTimeIndicator(
    BuildContext context, {
    required String label,
    required bool enabled,
    List<String> times = const [],
    // Add these optional parameters for custom sizing
    EdgeInsetsGeometry? padding,
    double? minWidth,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      // Use the passed padding or fallback to the default (horizontal: 10, vertical: 6)
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 8),
      // Use the passed minWidth or fallback to the default (80)
      constraints: BoxConstraints(minWidth: minWidth ?? 80),
      decoration: BoxDecoration(
        color: enabled
            ? themeProvider.selectedColor.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: enabled ? themeProvider.selectedColor : Colors.grey,
            width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(enabled ? Icons.check_circle : Icons.circle,
              color: enabled ? themeProvider.selectedColor : Colors.grey,
              size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.small.copyWith(
                        color:
                            enabled ? themeProvider.selectedColor : Colors.grey,
                        fontSize: 12)),
                if (enabled && times.isNotEmpty)
                  ...times.map((t) => Text(t,
                      style: AppTextStyles.small.copyWith(
                          color: Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.w500))),
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
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_errorLoadingStatus) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
                child: Text('Failed to load status',
                    style: AppTextStyles.body
                        .copyWith(fontSize: 14, color: Colors.red))),
            IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadPrayerTimesStatus),
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
            _buildPrayerTimeIndicator(context, label: 'Alarms', enabled: true),
            _buildPrayerTimeIndicator(context,
                label: 'Reminders', enabled: true),
            _buildPrayerTimeIndicator(context,
                label: 'Namaz', enabled: _namazEnabled),
            _buildPrayerTimeIndicator(context,
                label: 'Sunrise/Sunset', enabled: _sunriseEnabled),
            _buildPrayerTimeIndicator(
              context,
              label: 'Jain',
              enabled: _jainEnabled,
              // Example: Make it larger (Wider with more vertical padding)
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minWidth: 70,
            ), // Added Jain Indicator
            IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadPrayerTimesStatus),
          ],
        ),
      ),
    );
  }

  Future<void> _showTimePickerAndSync() async {
    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!),
    );

    if (selectedTime != null) {
      if (!isWifiConnected || !connectionStatus.contains(_targetSsid)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text("Please connect to IoGen_Speaker Wi-Fi to sync time")));
        return;
      }
      final now = DateTime.now();
      DateTime selectedDateTime = DateTime(
          now.year, now.month, now.day, selectedTime.hour, selectedTime.minute);
      if (selectedDateTime.isBefore(now)) {
        selectedDateTime = selectedDateTime.add(const Duration(days: 1));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text("Set for tomorrow: ${selectedTime.format(context)}")));
      }
      try {
        await BellService().syncTime(context, selectedTime: selectedDateTime);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Time synced: ${selectedTime.format(context)}")));
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Sync failed: $e")));
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
      if (index == 1) _musicTabLogic.setSelectedTab(0);
      _isFabMenuOpen = false;
    });

    if (index == 0) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted &&
            isWifiConnected &&
            connectionStatus.contains(_targetSsid)) {
          _loadPrayerTimesStatus();
        }
      });
    }
  }

  Widget _buildFabOption(String title, bool isChecked) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          _hideFabMenuOverlay();
          await Future.delayed(const Duration(milliseconds: 100));

          if (!mounted) return;

          switch (title) {
            case 'Alarm':
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AlarmPage()));
              break;
            case 'Reminder':
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ReminderPage()));
              break;
            case 'Astro':
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ReligiousAlarms()));
              break;
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: themeProvider.selectedColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int hour, int minute) =>
      DateFormat.jm().format(DateTime(2000, 1, 1, hour, minute));

  Widget _buildDaysRow(int days, Color selectedColor) {
    final List<String> abbr = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (i) {
        final active = (days & (1 << (i + 1 == 7 ? 7 : i + 1))) != 0;
        return Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: Text(abbr[i],
              style: AppTextStyles.subheading.copyWith(
                  color: active ? selectedColor : Colors.grey,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final ScrollController _scrollController = ScrollController();
    final today = DateTime.now();
    final selectedDay = _calendarLogic.selectedDay;

    final List<Widget> screens = [
      // === PLANNER SCREEN ===
      SingleChildScrollView(
        controller: _scrollController,
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
              Text(connectionStatus,
                  style: AppTextStyles.body, textAlign: TextAlign.center),
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
                                  blurRadius: 5)
                            ],
                          ),
                          child: TableCalendar(
                            firstDay: _calendarLogic.firstDay,
                            lastDay: _calendarLogic.lastDay,
                            focusedDay: _calendarLogic.focusedDay,
                            selectedDayPredicate: (day) =>
                                isSameDay(day, selectedDay),
                            onDaySelected: _onDaySelected,
                            onPageChanged: _onPageChanged,
                            calendarFormat: CalendarFormat.week,
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleTextStyle: AppTextStyles.subheading
                                  .copyWith(fontWeight: FontWeight.bold),
                              titleCentered: false,
                              leftChevronVisible: true,
                              rightChevronVisible: true,
                            ),
                            daysOfWeekStyle: DaysOfWeekStyle(
                              weekdayStyle: AppTextStyles.small,
                              weekendStyle: AppTextStyles.small,
                              dowTextFormatter: (date, locale) =>
                                  DateFormat.E(locale)
                                      .format(date)
                                      .toUpperCase(),
                            ),
                            calendarStyle: CalendarStyle(
                              todayDecoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  shape: BoxShape.circle),
                              todayTextStyle: AppTextStyles.body
                                  .copyWith(fontWeight: FontWeight.bold),
                              selectedDecoration: BoxDecoration(
                                  color: themeProvider.selectedColor,
                                  shape: BoxShape.circle),
                              selectedTextStyle: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
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
                                  offset: const Offset(0, -2))
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
                                      : DateFormat('MMMM d, y')
                                          .format(selectedDay),
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
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))),
                                  ),
                                ],
                                if (_errorLoadingAlarmSongs) ...[
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                            child: Text(
                                                'Failed to load alarm songs',
                                                style: AppTextStyles.body
                                                    .copyWith(
                                                        fontSize: 14,
                                                        color: Colors.red))),
                                        IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.refresh,
                                                size: 20),
                                            onPressed: _loadPrayerTimesStatus),
                                      ],
                                    ),
                                  ),
                                ],
                                if (!_loadingAlarmSongs &&
                                    !_errorLoadingAlarmSongs) ...[
                                  Builder(builder: (context) {
                                    final alarmList = _alarmSongs
                                        .where((s) =>
                                            s.isScheduledForDay(selectedDay) &&
                                            s.startTimestamp == 0)
                                        .toList();
                                    final reminderList = _alarmSongs
                                        .where((s) =>
                                            s.isScheduledForDay(selectedDay) &&
                                            s.startTimestamp != 0)
                                        .toList();

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (alarmList.isNotEmpty) ...[
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 8, top: 8, bottom: 8),
                                            child: Text('Alarms',
                                                style: AppTextStyles.subheading
                                                    .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.black87)),
                                          ),
                                          ...alarmList
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            final index = entry.key;
                                            final song = entry.value;
                                            final timeString = _formatTime(
                                                song.hour, song.minute);
                                            final isChecked =
                                                song.status == 1 &&
                                                    song.isPast(selectedDay,
                                                        DateTime.now());
                                            final isLast =
                                                index == alarmList.length - 1;

                                            return GestureDetector(
                                              onLongPress: () =>
                                                  _showAlarmDetailsDialog(song),
                                              child: ScheduleItem(
                                                time: timeString,
                                                title: '',
                                                isChecked: isChecked,
                                                isLast: isLast,
                                                icon: Icons.alarm,
                                                days: song.days,
                                                selectedColor:
                                                    themeProvider.selectedColor,
                                              ),
                                            );
                                          }),
                                        ],
                                        if (reminderList.isNotEmpty) ...[
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 8, top: 8, bottom: 8),
                                            child: Text('Reminders',
                                                style: AppTextStyles.subheading
                                                    .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.black87)),
                                          ),
                                          ...reminderList
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            final index = entry.key;
                                            final song = entry.value;
                                            final timeString = _formatTime(
                                                song.hour, song.minute);
                                            final isChecked =
                                                song.status == 1 &&
                                                    song.isPast(selectedDay,
                                                        DateTime.now());
                                            final isLast = index ==
                                                reminderList.length - 1;

                                            return GestureDetector(
                                              // 1. Trigger the existing dialog on long press, passing the reminder 'song'
                                              onLongPress: () =>
                                                  _showRemainderDetailsDialog(song),
                                              child: ScheduleItem(
                                                time: timeString,
                                                title: '',
                                                isChecked: isChecked,
                                                isLast: isLast,
                                                icon: Icons
                                                    .notifications_outlined,
                                                days: song.days,
                                                selectedColor:
                                                    themeProvider.selectedColor,
                                              ),
                                            );

                                            return ScheduleItem(
                                              time: timeString,
                                              title: '',
                                              isChecked: isChecked,
                                              isLast: isLast,
                                              icon:
                                                  Icons.notifications_outlined,
                                              days: song.days,
                                              selectedColor:
                                                  themeProvider.selectedColor,
                                            );
                                          }),
                                        ],
                                        if (_namazEnabled &&
                                            _namazTimes.isNotEmpty) ...[
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 8, top: 8, bottom: 8),
                                            child: Text('Namaz',
                                                style: AppTextStyles.subheading
                                                    .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.black87)),
                                          ),
                                          ..._namazTimes
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            final index = entry.key;
                                            final t = entry.value;
                                            String fileName = 'Namaz';
                                            String timeStr = t;
                                            if (t.contains(': ')) {
                                              final parts = t.split(': ');
                                              if (parts.length >= 2) {
                                                fileName = parts[0];
                                                timeStr = parts[1];
                                              }
                                            }
                                            int hour = 0, minute = 0;
                                            try {
                                              final timeParts =
                                                  timeStr.split(':');
                                              hour = int.parse(timeParts[0]);
                                              minute = int.parse(timeParts[1]);
                                            } catch (e) {
                                              return const SizedBox.shrink();
                                            }
                                            final timeString =
                                                _formatTime(hour, minute);
                                            final songDateTime = DateTime(
                                                selectedDay.year,
                                                selectedDay.month,
                                                selectedDay.day,
                                                hour,
                                                minute);
                                            final isChecked = songDateTime
                                                .isBefore(DateTime.now());
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8),
                                              child: ScheduleItem(
                                                time: timeString,
                                                title: fileName,
                                                isChecked: isChecked,
                                                isLast: index ==
                                                    _namazTimes.length - 1,
                                                icon: Icons.mosque_outlined,
                                              ),
                                            );
                                          }),
                                        ],
                                        if (_sunriseEnabled &&
                                            _poojaTimes.isNotEmpty) ...[
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 8, top: 8, bottom: 8),
                                            child: Text('Sunrise/Sunset',
                                                style: AppTextStyles.subheading
                                                    .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.black87)),
                                          ),
                                          ..._poojaTimes
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            final index = entry.key;
                                            final t = entry.value;
                                            String fileName = 'Pooja';
                                            String timeStr = t;
                                            if (t.contains(': ')) {
                                              final parts = t.split(': ');
                                              if (parts.length >= 2) {
                                                fileName = parts[0];
                                                timeStr = parts[1];
                                              }
                                            }
                                            int hour = 0, minute = 0;
                                            try {
                                              final timeParts =
                                                  timeStr.split(':');
                                              hour = int.parse(timeParts[0]);
                                              minute = int.parse(timeParts[1]);
                                            } catch (e) {
                                              return const SizedBox.shrink();
                                            }
                                            final timeString =
                                                _formatTime(hour, minute);
                                            final songDateTime = DateTime(
                                                selectedDay.year,
                                                selectedDay.month,
                                                selectedDay.day,
                                                hour,
                                                minute);
                                            final isChecked = songDateTime
                                                .isBefore(DateTime.now());
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8),
                                              child: ScheduleItem(
                                                time: timeString,
                                                title: fileName,
                                                isChecked: isChecked,
                                                isLast: index ==
                                                    _poojaTimes.length - 1,
                                                icon: Icons.wb_sunny,
                                              ),
                                            );
                                          }),
                                        ],
                                        // === JAIN PRAYERS SECTION START ===
                                        if (_jainEnabled &&
                                            _jainTimes.isNotEmpty) ...[
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 8, top: 8, bottom: 8),
                                            child: Text('Jain Prayers',
                                                style: AppTextStyles.subheading
                                                    .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.black87)),
                                          ),
                                          ..._jainTimes
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            final index = entry.key;
                                            final t = entry.value;
                                            String fileName = 'Jain Prayer';
                                            String timeStr = t;
                                            // Same parsing logic as Namaz/Pooja
                                            if (t.contains(': ')) {
                                              final parts = t.split(': ');
                                              if (parts.length >= 2) {
                                                fileName = parts[0];
                                                timeStr = parts[1];
                                              }
                                            }
                                            int hour = 0, minute = 0;
                                            try {
                                              final timeParts =
                                                  timeStr.split(':');
                                              hour = int.parse(timeParts[0]);
                                              minute = int.parse(timeParts[1]);
                                            } catch (e) {
                                              return const SizedBox.shrink();
                                            }
                                            final timeString =
                                                _formatTime(hour, minute);
                                            final songDateTime = DateTime(
                                                selectedDay.year,
                                                selectedDay.month,
                                                selectedDay.day,
                                                hour,
                                                minute);
                                            final isChecked = songDateTime
                                                .isBefore(DateTime.now());
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8),
                                              child: ScheduleItem(
                                                time: timeString,
                                                title: fileName,
                                                isChecked: isChecked,
                                                isLast: index ==
                                                    _jainTimes.length - 1,
                                                icon: Icons
                                                    .spa, // Specific Icon for Jain
                                              ),
                                            );
                                          }),
                                        ],
                                        // === JAIN PRAYERS SECTION END ===
                                        if (alarmList.isEmpty &&
                                            reminderList.isEmpty &&
                                            (!_namazEnabled ||
                                                _namazTimes.isEmpty) &&
                                            (!_sunriseEnabled ||
                                                _poojaTimes.isEmpty) &&
                                            (!_jainEnabled ||
                                                _jainTimes.isEmpty))
                                          Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Text(
                                                'No alarms or reminders scheduled for this day',
                                                style: AppTextStyles.body
                                                    .copyWith(
                                                        color: Colors.grey)),
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
      // === MUSIC LIBRARY ===
      MusicLibrary(tabLogic: _musicTabLogic),
      // === PROFILE ===
      ProfileScreen(),
    ];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Image.asset('assets/appbar_icon.png',
              height: 40, fit: BoxFit.contain),
        ),
        body: screens[_selectedIndex],
        floatingActionButton: _selectedIndex == 0
            ? FloatingActionButton(
          onPressed: () {
            if (_fabMenuOverlayEntry != null) {
              _hideFabMenuOverlay();
            } else {
              _showFabMenuOverlay();
            }
          },
          backgroundColor: themeProvider.selectedColor,
          shape: const CircleBorder(),
          child: AnimatedRotation(
            turns: _fabMenuOverlayEntry != null ? 0.125 : 0, // 45° → X
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _fabMenuOverlayEntry != null
                  ? Icons.close
                  : Icons.edit_calendar_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
        )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
        bottomNavigationBar: SizedBox(
          height: 90,
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
                      color: themeProvider.selectedColor),
                  label: ""),
              BottomNavigationBarItem(
                  icon: _buildNavItem(
                      isSelected: _selectedIndex == 1,
                      selectedIcon: Icons.music_note,
                      unselectedIcon: Icons.music_note_outlined,
                      label: "Library",
                      color: themeProvider.selectedColor),
                  label: ""),
              BottomNavigationBarItem(
                  icon: _buildNavItem(
                      isSelected: _selectedIndex == 2,
                      selectedIcon: Icons.person,
                      unselectedIcon: Icons.person_outline,
                      label: "Profile",
                      color: themeProvider.selectedColor),
                  label: ""),
            ],
          ),
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
        Icon(isSelected ? selectedIcon : unselectedIcon,
            color: isSelected ? color : Colors.grey),
        const SizedBox(height: 4),
        Text(label,
            style: AppTextStyles.small.copyWith(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? color : Colors.grey)),
        const Spacer(),
        Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
                color: isSelected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(50))),
      ],
    ),
  );
}