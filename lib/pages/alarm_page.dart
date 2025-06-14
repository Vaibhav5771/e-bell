import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../alarm/alarm_model.dart';
import '../alarm/permission_handler.dart';
import '../alarm/shared_preferences.dart';
import '../alarm/alarm_service.dart';
import '../services/bell_service.dart';
import 'package:intl/intl.dart';

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
    bool hasNotificationPermission =
        await PermissionHandler.requestNotificationPermission();
    if (!hasNotificationPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Notification permission is required to set alarms.')),
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
    switch (alarm.sound) {
      case 'file1':
        mp3File = 'file1.mp3';
        break;
      case 'file2':
        mp3File = 'file2.mp3';
        break;
      case 'file3':
        mp3File = 'file3.mp3';
        break;
      default:
        mp3File = 'file1.mp3';
    }

    final now = DateTime.now();
    DateTime alarmDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      alarm.time.hour,
      alarm.time.minute,
    );
    if (alarmDateTime.isBefore(now)) {
      alarmDateTime = alarmDateTime.add(const Duration(days: 1));
    }

// Format as MM:dd:yyyy:hh:mm:ss:a for logging
    final fullFormat =
        DateFormat('MM:dd:yyyy:hh:mm:ss:a').format(alarmDateTime);
    debugPrint("Full alarm time format: $fullFormat");

// Use HH:mm (24-hour) for server
    final timeFormat = DateFormat('HH:mm').format(alarmDateTime);
    debugPrint("Setting alarm time: $timeFormat (24-hour) for $mp3File");

    bool serverSuccess = await BellService()
        .setAlarmTime(mp3File, alarmDateTime, context, timeFormat);
    if (serverSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Alarm set on server for $timeFormat with $mp3File')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to set alarm on server')),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alarm saved successfully!')),
    );

    Navigator.pop(context);
  }

  Future<void> _playAlarmSound(String sound) async {
    String audioPath;
    switch (sound) {
      case 'file1':
        audioPath = 'file1.mp3';
        break;
      case 'file2':
        audioPath = 'file2.mp3';
        break;
      case 'file3':
        audioPath = 'file3.mp3';
        break;
      default:
        audioPath = 'file1.mp3';
    }

    try {
      debugPrint('Attempting to play sound: assets/$audioPath');
      await _audioPlayer.play(AssetSource(audioPath));
      debugPrint('Sound played successfully: assets/$audioPath');
    } catch (e) {
      debugPrint('Error playing alarm sound: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing $sound: $e')),
      );
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    final timeTextSize = isSmallScreen ? 28.0 : 32.0;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 5.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Center(
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.orange, fontSize: 16),
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
            GestureDetector(
              onTap: _selectTime,
              child: Container(
                height: isSmallScreen ? 180.0 : 220.0,
                color: Colors.grey[50],
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    _selectedTime.format(context).padLeft(5, '0'),
                    style: TextStyle(
                      fontSize: timeTextSize + 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
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
          options: const ['file1', 'file2', 'file3', 'Custom...'],
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
