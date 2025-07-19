import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import '../alarm/alarm_model.dart';
import '../alarm/permission_handler.dart';
import '../alarm/shared_preferences.dart';
import '../alarm/alarm_service.dart';
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
  String _alarmLabel = '';
  String _repeatOption = 'Never';
  String _soundOption = 'file1';
  String _period = TimeOfDay.now().hour < 12 ? 'AM' : 'PM'; // Initialize AM/PM
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> _soundOptions = ['file1', 'file2', 'file3'];

  @override
  void initState() {
    super.initState();
    _loadUploadedFiles();
  }

  Future<void> _loadUploadedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final uploadedFiles = prefs.getStringList('uploaded_files') ?? [];
    setState(() {
      _soundOptions = ['file1', 'file2', 'file3', ...uploadedFiles];
      if (!_soundOptions.contains(_soundOption)) {
        _soundOption = _soundOptions.isNotEmpty ? _soundOptions[0] : 'file1';
      }
    });
  }

  @override
  void dispose() {
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
    bool hasNotificationPermission =
    await PermissionHandler.requestNotificationPermission();
    if (!hasNotificationPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Notification permission is required to set alarms.')),
      );
      return;
    }

    final alarm = AlarmModel(
      id: await AlarmModel.generateUniqueId(),
      time: _selectedTime,
      label: _alarmLabel.isEmpty ? 'Alarm' : _alarmLabel,
      repeatOption: _repeatOption,
      sound: _soundOption,
      isSnoozeEnabled: _isSnoozeEnabled,
      isActive: true,
    );

    await SharedPreferencesService.saveAlarm(alarm);

    bool scheduled = await AlarmService.scheduleAlarm(alarm);
    if (!scheduled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to schedule alarm. Go to Settings > Apps > eBell > Alarms & Reminders and enable "Allow setting exact alarms".',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    String mp3File;
    if (_soundOption == 'file1' || _soundOption == 'file2' || _soundOption == 'file3') {
      mp3File = '${_soundOption.toUpperCase()}.MP3';
    } else {
      mp3File = _soundOption.toUpperCase();
    }

    String url = 'http://192.168.2.1/settime/$mp3File';
    String data = _formatDataString(_selectedTime);

    setState(() => isLoading = true);

    try {
      final response = await http.post(Uri.parse(url), body: data);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alarm set on server for ${alarm.time.format(context)} with $mp3File')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set alarm on server: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error setting alarm: Make sure you're connected to the speaker's Wi-Fi. Error: $e")),
      );
    }

    setState(() => isLoading = false);

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
    final timeTextSize = isSmallScreen ? 28.0 : 32.0;

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
                  // Hour picker
                  SizedBox(
                    width: isSmallScreen ? 80 : 100,
                    child: ListWheelScrollView.useDelegate(
                      itemExtent: 60,
                      perspective: 0.005,
                      diameterRatio: 1.2,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (index) {
                        setState(() {
                          int hour = (index % 12) + 1; // Cycle 1 to 12
                          _selectedTime = _selectedTime.replacing(
                            hour: _period == 'AM'
                                ? (hour == 12 ? 0 : hour)
                                : (hour == 12 ? 12 : hour + 12),
                          );
                        });
                      },
                      childDelegate: ListWheelChildLoopingListDelegate(
                        children: List.generate(12, (i) {
                          final displayHour = (i % 12) + 1; // Generate 1 to 12
                          return Center(
                            child: Text(
                              displayHour.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: displayHour == (_selectedTime.hourOfPeriod == 0 ? 12 : _selectedTime.hourOfPeriod)
                                    ? themeProvider.selectedColor
                                    : Colors.black,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  // Minute picker
                  SizedBox(
                    width: isSmallScreen ? 80 : 100,
                    child: ListWheelScrollView.useDelegate(
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

                  // AM/PM picker
                  SizedBox(
                    width: isSmallScreen ? 80 : 100,
                    child: ListWheelScrollView(
                      itemExtent: 60,
                      perspective: 0.005,
                      diameterRatio: 1.2,
                      physics: const FixedExtentScrollPhysics(),
                      controller: FixedExtentScrollController(initialItem: _period == 'AM' ? 0 : 1),
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _period = index == 0 ? 'AM' : 'PM';
                          int currentHour = _selectedTime.hour;
                          if (_period == 'AM' && currentHour >= 12) {
                            _selectedTime = _selectedTime.replacing(hour: currentHour - 12);
                          } else if (_period == 'PM' && currentHour < 12) {
                            _selectedTime = _selectedTime.replacing(hour: currentHour + 12);
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
                    title: 'Repeat',
                    value: _repeatOption,
                    onTap: _selectRepeatOption,
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
                    value: _soundOption,
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

  void _selectRepeatOption() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return _buildOptionSelectionSheet(
          title: 'Repeat',
          options: const [
            'Never',
            'Every Day',
            'Weekdays',
            'Weekends',
            'Custom...'
          ],
          selectedOption: _repeatOption,
          onSelect: (value) {
            setState(() => _repeatOption = value);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _selectSoundOption() {
    showModalBottomSheet(
      context: context,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ...options.map((option) => ListTile(
          title: Text(option),
          trailing: option == selectedOption
              ? Icon(Icons.check, color: themeProvider.selectedColor)
              : null,
          onTap: () => onSelect(option),
        )),
        const SizedBox(height: 8),
      ],
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