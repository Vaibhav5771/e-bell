import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../alarm/alarm_model.dart';
import '../alarm/permission_handler.dart';
import '../alarm/shared_preferences.dart';
import '../alarm/alarm_service.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  bool _isSnoozeEnabled = true;
  String _alarmLabel = '';
  String _repeatOption = 'Never';
  String _soundOption = 'Opening (default)';
  final AudioPlayer _audioPlayer = AudioPlayer();

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

  Future<void> _saveAlarm() async {
    // Request notification permissions
    bool hasNotificationPermission = await PermissionHandler.requestNotificationPermission();
    if (!hasNotificationPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification permission is required to set alarms.')),
      );
      return;
    }

    // Create AlarmModel with unique ID
    final alarm = AlarmModel(
      id: await AlarmModel.generateUniqueId(),
      time: _selectedTime,
      label: _alarmLabel.isEmpty ? 'Alarm' : _alarmLabel,
      repeatOption: _repeatOption,
      sound: _soundOption,
      isSnoozeEnabled: _isSnoozeEnabled,
      isActive: true,
    );

    // Save to SharedPreferences
    await SharedPreferencesService.saveAlarm(alarm);

    // Schedule the alarm
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

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alarm saved successfully!')),
    );

    // Navigate back
    Navigator.pop(context);
  }

  Future<void> _playAlarmSound(String sound) async {
    String audioPath;
    switch (sound) {
      case 'Beep':
        audioPath = 'beep.mp3';
        break;
      case 'Chime':
        audioPath = 'chime.mp3';
        break;
      case 'Radar':
        audioPath = 'radar.mp3';
        break;
      case 'Opening (default)':
      default:
        audioPath = 'opening.mp3';
    }

    try {
      print('Attempting to play sound: assets/$audioPath');
      await _audioPlayer.play(AssetSource(audioPath));
      print('Sound played successfully: assets/$audioPath');
    } catch (e) {
      print('Error playing alarm sound: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing $sound: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    final timePickerHeight = isSmallScreen ? 180.0 : 220.0;
    final timeTextSize = isSmallScreen ? 28.0 : 32.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.orange),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Alarm',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _saveAlarm,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Time Picker
            Container(
              height: timePickerHeight,
              color: Colors.grey[50],
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildTimePickerColumn(
                      start: 1,
                      end: 12,
                      selected: _selectedTime.hour % 12 == 0 ? 12 : _selectedTime.hour % 12,
                      textSize: timeTextSize,
                      onSelectedItemChanged: (value) {
                        setState(() {
                          int newHour = value == 12 ? 0 : value;
                          if (_selectedTime.hour >= 12) newHour += 12;
                          _selectedTime = TimeOfDay(hour: newHour, minute: _selectedTime.minute);
                        });
                      },
                    ),
                    Text(
                      ':',
                      style: TextStyle(
                        fontSize: timeTextSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    _buildTimePickerColumn(
                      start: 0,
                      end: 59,
                      selected: _selectedTime.minute,
                      textSize: timeTextSize,
                      onSelectedItemChanged: (value) {
                        setState(() {
                          _selectedTime = TimeOfDay(hour: _selectedTime.hour, minute: value);
                        });
                      },
                    ),
                    const SizedBox(width: 16),
                    _buildTimePickerColumn(
                      start: 0,
                      end: 1,
                      selected: _selectedTime.hour < 12 ? 0 : 1,
                      textSize: timeTextSize - 8,
                      items: const ['AM', 'PM'],
                      onSelectedItemChanged: (value) {
                        setState(() {
                          int newHour = _selectedTime.hour % 12;
                          if (value == 1) newHour += 12; // PM
                          if (value == 0 && _selectedTime.hour >= 12) newHour -= 12; // AM
                          _selectedTime = TimeOfDay(hour: newHour, minute: _selectedTime.minute);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Options List
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
                    onSwitchChanged: (value) => setState(() => _isSnoozeEnabled = value),
                  ),
                  _buildDivider(),
                  ElevatedButton(
                    onPressed: () => _playAlarmSound(_soundOption),
                    child: const Text('Test Selected Sound'),
                  ),
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
          options: const ['Never', 'Every Day', 'Weekdays', 'Weekends', 'Custom...'],
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
          options: const ['Opening (default)', 'Radar', 'Beep', 'Chime', 'Custom...'],
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...options.map((option) => ListTile(
          title: Text(option),
          trailing: option == selectedOption
              ? const Icon(Icons.check, color: Colors.orange)
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
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
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
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          const SizedBox(width: 4),
          if (!isSwitch && !isTextField)
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildTimePickerColumn({
    required int start,
    required int end,
    int? selected,
    List<String>? items,
    required double textSize,
    required Function(int) onSelectedItemChanged,
  }) {
    final itemCount = items != null ? items.length : (end - start + 1);
    final itemExtent = textSize + 20;
    final selectedIndex = items != null
        ? (selected ?? 0)
        : (selected ?? start) - start;

    if (items != null) {
      return SizedBox(
        width: 70,
        child: ListWheelScrollView.useDelegate(
          controller: FixedExtentScrollController(initialItem: selectedIndex),
          itemExtent: itemExtent,
          diameterRatio: 1.5,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onSelectedItemChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (context, i) {
              final value = items[i];
              final isSelected = i == selectedIndex;
              return Center(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isSelected ? textSize : textSize - 4,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.black : Colors.grey,
                  ),
                ),
              );
            },
            childCount: itemCount,
          ),
        ),
      );
    } else {
      const overScrollItems = 1000;
      return SizedBox(
        width: 80,
        child: ListWheelScrollView.useDelegate(
          controller: FixedExtentScrollController(
            initialItem: selectedIndex + (overScrollItems ~/ 2) * itemCount,
          ),
          itemExtent: itemExtent,
          diameterRatio: 1.5,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (i) {
            final adjustedIndex = (i % itemCount) + start;
            onSelectedItemChanged(adjustedIndex);
          },
          childDelegate: ListWheelChildLoopingListDelegate(
            children: List.generate(itemCount, (i) {
              final value = (start + i).toString().padLeft(2, '0');
              final isSelected = (start + (i % itemCount)) == selected;
              return Center(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isSelected ? textSize : textSize - 4,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.black : Colors.grey,
                  ),
                ),
              );
            }),
          ),
        ),
      );
    }
  }
}