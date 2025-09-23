import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isSnoozeEnabled = true;
  bool _isRepeatEnabled = false;
  String _alarmLabel = '';
  String _soundOption = '';
  String _period = TimeOfDay.now().hour < 12 ? 'AM' : 'PM';
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> _soundOptions = [];
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _periodController;
  bool isLoading = false;
  List<bool> _selectedDays = List.filled(7, false); // [Sun, Mon, Tue, Wed, Thu, Fri, Sat]

  @override
  void initState() {
    super.initState();
    _loadUploadedFiles();

    int hourIndex = _selectedTime.hourOfPeriod - 1; // 0-based index
    hourIndex = hourIndex == -1 ? 11 : hourIndex;

    _hourController = FixedExtentScrollController(initialItem: hourIndex);
    _minuteController = FixedExtentScrollController(initialItem: _selectedTime.minute);
    _periodController = FixedExtentScrollController(initialItem: _selectedTime.period == DayPeriod.am ? 0 : 1);
    print('Initial state: _isRepeatEnabled=$_isRepeatEnabled, _selectedDays=$_selectedDays');
  }

  Future<void> _loadUploadedFiles() async {
    try {
      final response = await http.get(Uri.parse('http://192.168.2.1/alarmsong')).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request to IoT device timed out');
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final filesData = jsonData['Data'] as List<dynamic>?;
        if (filesData != null && filesData.isNotEmpty) {
          final files = (filesData[0]['files'] as List<dynamic>?)?.map((file) {
            return (file as List<dynamic>)[0] as String;
          }).toList() ?? [];
          print('Fetched filenames: $files');
          setState(() {
            _soundOptions = files
                .where((file) =>
            !file.contains('/') &&
                (file.toLowerCase().endsWith('.mp3') ||
                    file.toLowerCase().endsWith('.wav')))
                .toList();
            _soundOption = _soundOptions.isNotEmpty ? _soundOptions[0] : '';
          });
          if (_soundOptions.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No valid audio files (MP3 or WAV) found in root directory.',
                  style: AppTextStyles.body,
                ),
              ),
            );
          }
        } else {
          setState(() {
            _soundOptions = [];
            _soundOption = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No sound files found in root directory.',
                style: AppTextStyles.body,
              ),
            ),
          );
        }
      } else {
        setState(() {
          _soundOptions = [];
          _soundOption = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to fetch sounds from device: ${response.statusCode}',
              style: AppTextStyles.body,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _soundOptions = [];
        _soundOption = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error fetching sounds: Ensure you are connected to the speaker\'s Wi-Fi. Error: $e',
            style: AppTextStyles.body,
          ),
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

  Widget _buildDaysSelector() {
    print('Building days selector, _isRepeatEnabled=$_isRepeatEnabled');
    final themeProvider = Provider.of<ThemeProvider>(context);
    final dayAbbreviations = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (index) {
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDays[index] = !_selectedDays[index];
                print('Day ${dayAbbreviations[index]} toggled: ${_selectedDays[index]}');
                if (_selectedDays.every((day) => day)) {
                  _isRepeatEnabled = true;
                }
              });
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _selectedDays[index]
                    ? themeProvider.selectedColor
                    : Colors.transparent,
                border: Border.all(
                  color: _selectedDays[index]
                      ? themeProvider.selectedColor
                      : Colors.grey,
                ),
              ),
              child: Center(
                child: Text(
                  dayAbbreviations[index],
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _selectedDays[index] ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  String _getSelectedDaysString() {
    List<String> dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    List<String> selectedDayNames = [];
    for (int i = 0; i < _selectedDays.length; i++) {
      if (_selectedDays[i]) {
        selectedDayNames.add(dayNames[i]);
      }
    }
    return selectedDayNames.isEmpty ? 'Daily' : selectedDayNames.join(', ');
  }

  int _calculateWeekBitmask() {
    const List<int> dayBitmasks = [128, 2, 4, 8, 16, 32, 64]; // [Sun, Mon, Tue, Wed, Thu, Fri, Sat]
    int week = 0;
    for (int i = 0; i < _selectedDays.length; i++) {
      if (_selectedDays[i]) {
        week |= dayBitmasks[i];
      }
    }
    return week == 0 ? 254 : week; // Default to 254 if no days selected (Daily)
  }

  Future<void> _saveAlarm() async {
    String soundFile = _soundOption;
    int hr = _selectedTime.hour;
    int mn = _selectedTime.minute;
    int week;
    int sEpoch = 0;
    int eEpoch = 0;
    int active = 1; // Assuming alarm is active
    int alarmType = 1; // 1 for alarm

    if (_isRepeatEnabled) {
      week = _calculateWeekBitmask();
    } else {
      final now = DateTime.now();
      DateTime alarmDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        hr,
        mn,
      );

      if (alarmDateTime.isBefore(now)) {
        alarmDateTime = alarmDateTime.add(const Duration(days: 1));
      }

      hr = alarmDateTime.hour;
      mn = alarmDateTime.minute;
      const List<int> dayBitmasks = [2, 4, 8, 16, 32, 64, 128]; // [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
      week = dayBitmasks[alarmDateTime.weekday - 1];
    }

    String data = '$hr,$mn,$sEpoch,$eEpoch,$active,$week,$alarmType';
    String url = 'http://192.168.2.1/settime/$soundFile';
    String curlCommand = 'curl -X POST $url -d "$data"';

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
            content: Text(
              '✅ Alarm set!\n$curlCommand',
              style: AppTextStyles.body,
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Failed to set alarm: ${response.statusCode} - ${response.reasonPhrase}',
              style: AppTextStyles.body,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Error setting alarm. Error: $e',
            style: AppTextStyles.body,
          ),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Center(
          child: Text(
            'Add Alarm',
            style: AppTextStyles.heading,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.check,
              color: _soundOptions.isEmpty ? Colors.grey : themeProvider.selectedColor,
            ),
            onPressed: _soundOptions.isEmpty ? null : _saveAlarm,
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
                              style: AppTextStyles.heading.copyWith(
                                fontSize: 32,
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
                              style: AppTextStyles.heading.copyWith(
                                fontSize: 32,
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
                            style: AppTextStyles.heading.copyWith(
                              fontSize: 32,
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
                    title: 'Repeat',
                    isSwitch: true,
                    switchValue: _isRepeatEnabled,
                    onSwitchChanged: (value) {
                      setState(() {
                        _isRepeatEnabled = value;
                        if (!value) {
                          _selectedDays = List.filled(7, false);
                        }
                        print('Repeat toggled: _isRepeatEnabled=$value');
                      });
                    },
                  ),
                  if (_isRepeatEnabled) _buildDaysSelector(),
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
                    value: _soundOption.isEmpty ? 'Select a sound' : _soundOption,
                    onTap: _soundOptions.isEmpty ? null : _selectSoundOption,
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
    if (_soundOptions.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _buildOptionSelectionSheet(
          title: 'Sound',
          options: _soundOptions,
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
              style: AppTextStyles.subheading.copyWith(fontWeight: FontWeight.bold),
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
                    option,
                    style: AppTextStyles.body,
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
        style: AppTextStyles.subheading.copyWith(fontWeight: FontWeight.bold),
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
                  hintStyle: AppTextStyles.body.copyWith(color: Colors.grey[600]),
                ),
                onChanged: onChanged,
              ),
            )
          else
            Text(
              value!,
              style: AppTextStyles.body.copyWith(color: Colors.grey[600]),
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