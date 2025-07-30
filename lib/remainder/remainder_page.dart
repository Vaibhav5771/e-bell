import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:e_bell/remainder/remainder_model.dart';
import 'package:e_bell/remainder/remainder_service.dart';
import 'package:e_bell/remainder/shared_preferences_remainder.dart';
import '../services/theme_state.dart';

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _period = TimeOfDay.now().hour < 12 ? 'AM' : 'PM';
  String _title = '';
  String _description = '';
  bool _isImportant = false;
  String _soundOption = '';
  List<String> _soundOptions = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadUploadedFiles();
  }

  Future<void> _loadUploadedFiles() async {
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
            _soundOptions = filenames;
            _soundOption = _soundOptions.isNotEmpty ? _soundOptions[0] : '';
          });
        } else {
          setState(() {
            _soundOptions = [];
            _soundOption = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No sound files found on device.')),
          );
        }
      } else {
        setState(() {
          _soundOptions = [];
          _soundOption = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch sounds from device: ${response.statusCode}'),
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
          content: Text('Error fetching sounds: Ensure you are connected to the speaker\'s Wi-Fi. Error: $e'),
        ),
      );
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }

  Future<void> _saveReminder() async {
    if (_title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    if (_selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    if (_soundOptions.isEmpty || _soundOption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sound files available. Please check the device connection.')),
      );
      return;
    }

    final reminderDateTime = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final reminder = ReminderModel(
      id: await ReminderModel.generateUniqueId(),
      title: _title,
      description: _description,
      startDateTime: reminderDateTime,
      endDateTime: reminderDateTime, // Same as start for non-recurring
      isImportant: _isImportant,
      sound: _soundOption,
      isActive: true,
    );

    await ReminderSharedPreferencesService.saveReminder(reminder);

    setState(() => isLoading = true);

    final scheduled = await ReminderService.scheduleReminder(reminder, _soundOptions);
    if (scheduled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder set for ${reminder.startDateTime} with ${_soundOption}'),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to set reminder on device')),
      );
    }

    setState(() => isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      backgroundColor: Colors.grey[50],
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
        title: const Text(
          'Add Reminder',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _soundOptions.isEmpty ? null : _saveReminder,
            child: Text(
              'Save',
              style: TextStyle(
                color: _soundOptions.isEmpty ? Colors.grey : themeProvider.selectedColor,
                fontSize: 16,
              ),
            ),
          ),
        ],
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: (value) => setState(() => _title = value),
              decoration: const InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(fontSize: 20),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            _buildDivider(),
            TextField(
              onChanged: (value) => setState(() => _description = value),
              decoration: const InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(fontSize: 16),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              maxLines: 1,
            ),
            _buildDivider(),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Select Date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            _buildCalendarPicker(),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Select Time',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            _buildTimePicker(),
            const SizedBox(height: 16),
            _buildDivider(),
            const SizedBox(height: 16),
            _buildOptionTile(
              context,
              title: 'Sound',
              value: _soundOption.isEmpty ? 'Select a sound' : _soundOption,
              onTap: _soundOptions.isEmpty ? null : _selectSoundOption,
            ),
            _buildDivider(),
            const SizedBox(height: 16),
            _buildOptionTile(
              context,
              title: 'Important',
              isSwitch: true,
              switchValue: _isImportant,
              onSwitchChanged: (value) => setState(() => _isImportant = value),
            ),
            _buildDivider(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarPicker() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return SizedBox(
      height: 350,
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: _onDaySelected,
        calendarFormat: CalendarFormat.month,
        availableGestures: AvailableGestures.none,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        calendarStyle: CalendarStyle(
          selectedDecoration: BoxDecoration(
            color: themeProvider.selectedColor,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: themeProvider.selectedColor.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Container(
      height: isSmallScreen ? 200.0 : 240.0,
      color: Colors.grey[50],
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: isSmallScreen ? 80 : 100,
            child: ListWheelScrollView.useDelegate(
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
                            (_selectedTime.hourOfPeriod == 0 ? 12 : _selectedTime.hourOfPeriod)
                            ? themeProvider.selectedColor
                            : Colors.black,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
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
                      color: period == _period ? themeProvider.selectedColor : Colors.black,
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
                    option,
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
        bool isSwitch = false,
        bool? switchValue,
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
          Text(
            value!,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}