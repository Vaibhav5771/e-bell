import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../alarm/alarm_model.dart';
import '../alarm/permission_handler.dart';
import '../alarm/shared_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/theme_state.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isSnoozeEnabled = true;
  bool _isRepeatEnabled = false; // New state for repeat toggle
  String _alarmLabel = '';
  String _soundOption = 'namaz/fajr.mp3';
  String _period = TimeOfDay.now().hour < 12 ? 'AM' : 'PM';
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> _soundOptions = ['namaz/fajr.mp3', 'namaz/sunrise.mp3', 'namaz/dhuhr.mp3'];
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _periodController;


  @override
  void initState() {
    super.initState();
    _loadUploadedFiles();

    int hourIndex = _selectedTime.hourOfPeriod - 1; // 0-based index
    hourIndex = hourIndex == -1 ? 11 : hourIndex;

    _hourController = FixedExtentScrollController(initialItem: hourIndex);
    _minuteController = FixedExtentScrollController(initialItem: _selectedTime.minute);
    _periodController = FixedExtentScrollController(initialItem: _selectedTime.period == DayPeriod.am ? 0 : 1);
  }


  Future<void> _loadUploadedFiles() async {
    List<String> defaultSounds = ['namaz/fajr.mp3', 'namaz/sunrise.mp3', 'namaz/dhuhr.mp3'];

    try {
      final response = await http.get(Uri.parse('http://192.168.2.1/')).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request to IoT device timed out');
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final alarmData = jsonData['alarmData'] as List<dynamic>?;
        if (alarmData != null && alarmData.isNotEmpty) {
          final filenames = (alarmData[0]['Filenames'] as List<dynamic>?)?.map((file) {
            return (file as List<dynamic>)[0] as String;
          }).toList() ?? [];
          setState(() {
            _soundOptions = filenames.isNotEmpty ? filenames : defaultSounds;
            if (!_soundOptions.contains(_soundOption)) {
              _soundOption = _soundOptions.isNotEmpty ? _soundOptions[0] : 'namaz/fajr.mp3';
            }
          });
        } else {
          setState(() {
            _soundOptions = defaultSounds;
            _soundOption = _soundOptions[0];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No sound files found on device. Using default sounds.')),
          );
        }
      } else {
        setState(() {
          _soundOptions = defaultSounds;
          _soundOption = _soundOptions[0];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch sounds from device: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _soundOptions = defaultSounds;
        _soundOption = _soundOptions[0];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching sounds: Ensure you are connected to the speaker\'s Wi-Fi. Error: $e'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }


  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Colors.grey[200],
    );
  }

  String _formatDataString(TimeOfDay time) {
    String hh = time.hour.toString().padLeft(2, '0');
    String mm = time.minute.toString().padLeft(2, '0');
    return "omomo${hh}ooo$mm";
  }

  Future<void> _saveAlarm() async {
    bool hasNotificationPermission = await PermissionHandler.requestNotificationPermission();
    if (!hasNotificationPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification permission is required to set alarms.')),
      );
      return;
    }

    bool hasExactAlarmPermission = await PermissionHandler.requestExactAlarmPermission();
    if (!hasExactAlarmPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Exact alarm permission is required to schedule alarms. Please enable it in system settings.'),
        ),
      );
      return;
    }

    final alarm = AlarmModel(
      id: await AlarmModel.generateUniqueId(),
      time: _selectedTime,
      label: _alarmLabel.isEmpty ? 'Alarm' : _alarmLabel,
      repeatOption: _isRepeatEnabled ? 'Daily' : 'Never', // Updated to use toggle state
      sound: _soundOption,
      isSnoozeEnabled: _isSnoozeEnabled,
      isActive: true,
    );

    await SharedPreferencesService.saveAlarm(alarm);

    String soundFile = _soundOption;

    final now = DateTime.now();
    final alarmDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final epochTime = (alarmDateTime.millisecondsSinceEpoch / 1000).floor().toString();

    String data = '$epochTime,${alarm.isActive ? 1 : 0},${alarm.isSnoozeEnabled ? 1 : 0}';
    String url = 'http://192.168.2.1/settime/$soundFile';

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(url),
        body: data,
        headers: {'Content-Type': 'text/plain'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alarm set on server for ${alarm.time.format(context)} with $soundFile'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set alarm on server: ${response.statusCode} - ${response.reasonPhrase}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error setting alarm: Ensure you are connected to the speaker\'s Wi-Fi. Error: $e'),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alarm saved successfully!')),
    );

    Navigator.pop(context);
  }

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 5.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: Text(
                'Cancel',
                style: TextStyle(color: themeProvider.selectedColor, fontSize: 16),
              ),
            ),
          ),
        ),
        title: const Center(
          child: Text(
            'Add Alarm',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveAlarm,
            child: Text(
              'Save',
              style: TextStyle(
                color: themeProvider.selectedColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: isSmallScreen ? 200.0 : 240.0,
              color: Colors.grey[50],
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hours
                  SizedBox(
                    width: isSmallScreen ? 80 : 100,
                    child: ListWheelScrollView.useDelegate(
                      controller: _hourController,
                      itemExtent: 60,
                      perspective: 0.005,
                      diameterRatio: 1.2,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (index) {
                        setState(() {
                          int hour = (index % 12) + 1;
                          _selectedTime = _selectedTime.replacing(
                            hour: _period == 'AM'
                                ? (hour == 12 ? 0 : hour)
                                : (hour == 12 ? 12 : hour + 12),
                          );
                        });
                      },
                      childDelegate: ListWheelChildLoopingListDelegate(
                        children: List.generate(12, (i) {
                          final displayHour = (i % 12) + 1;
                          return Center(
                            child: Text(
                              displayHour.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: displayHour ==
                                    (_selectedTime.hourOfPeriod == 0
                                        ? 12
                                        : _selectedTime.hourOfPeriod)
                                    ? themeProvider.selectedColor
                                    : Colors.black,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  // Minutes
                  SizedBox(
                    width: isSmallScreen ? 80 : 100,
                    child: ListWheelScrollView.useDelegate(
                      controller: _minuteController,
                      itemExtent: 60,
                      perspective: 0.005,
                      diameterRatio: 1.2,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _selectedTime = _selectedTime.replacing(minute: index % 60);
                        });
                      },
                      childDelegate: ListWheelChildLoopingListDelegate(
                        children: List.generate(60, (minute) {
                          return Center(
                            child: Text(
                              minute.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: minute == _selectedTime.minute
                                    ? themeProvider.selectedColor
                                    : Colors.black,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  // AM/PM
                  SizedBox(
                    width: isSmallScreen ? 80 : 100,
                    child: ListWheelScrollView(
                      controller: _periodController,
                      itemExtent: 60,
                      perspective: 0.005,
                      diameterRatio: 1.2,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _period = index == 0 ? 'AM' : 'PM';
                          int currentHour = _selectedTime.hour;
                          if (_period == 'AM' && currentHour >= 12) {
                            _selectedTime =
                                _selectedTime.replacing(hour: currentHour - 12);
                          } else if (_period == 'PM' && currentHour < 12) {
                            _selectedTime =
                                _selectedTime.replacing(hour: currentHour + 12);
                          }
                        });
                      },
                      children: ['AM', 'PM'].map((period) {
                        return Center(
                          child: Text(
                            period,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: period == _period
                                  ? themeProvider.selectedColor
                                  : Colors.black,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildOptionTile(
                    context,
                    title: 'Repeat Daily',
                    isSwitch: true,
                    switchValue: _isRepeatEnabled,
                    onSwitchChanged: (value) =>
                        setState(() => _isRepeatEnabled = value),
                  ),
                  _buildDivider(),
                  _buildOptionTile(
                    context,
                    title: 'Label',
                    isTextField: true,
                    value: _alarmLabel,
                    onChanged: (value) => setState(() => _alarmLabel = value),
                  ),
                  _buildDivider(),
                  _buildOptionTile(
                    context,
                    title: 'Sound',
                    value: _soundOption.split('/').last,
                    onTap: _selectSoundOption,
                  ),
                  _buildDivider(),
                  _buildOptionTile(
                    context,
                    title: 'Snooze',
                    isSwitch: true,
                    switchValue: _isSnoozeEnabled,
                    onSwitchChanged: (value) =>
                        setState(() => _isSnoozeEnabled = value),
                  ),
                  _buildDivider(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectSoundOption() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _buildOptionSelectionSheet(
          title: 'Sound',
          options: [..._soundOptions, 'Custom...'],
          selectedOption: _soundOption,
          onSelect: (value) {
            setState(() => _soundOption = value);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildOptionSelectionSheet({
    required String title,
    required List<String> options,
    required String selectedOption,
    required Function(String) onSelect,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.6;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                return ListTile(
                  title: Text(
                    option.split('/').last,
                    style: const TextStyle(fontSize: 16),
                  ),
                  trailing: option == selectedOption
                      ? Icon(Icons.check, color: themeProvider.selectedColor)
                      : null,
                  onTap: () => onSelect(option),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
      BuildContext context, {
        required String title,
        String? value,
        bool isTextField = false,
        bool isSwitch = false,
        bool? switchValue,
        Function(String)? onChanged,
        Function()? onTap,
        Function(bool)? onSwitchChanged,
      }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      trailing: isSwitch
          ? Switch(
        value: switchValue!,
        onChanged: onSwitchChanged,
        activeColor: Colors.lightGreen,
      )
          : Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isTextField)
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.4,
              child: TextField(
                textAlign: TextAlign.end,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Alarm',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                ),
                onChanged: onChanged,
              ),
            )
          else
            Text(
              value!,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          const SizedBox(width: 4),
          if (!isSwitch && !isTextField)
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}