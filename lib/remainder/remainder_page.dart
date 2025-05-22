import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key});

  @override
  _AddReminderScreenState createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime _fromDateTime = DateTime.now();
  DateTime _toDateTime = DateTime.now();
  bool _isImportant = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _fromDateTime = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, _fromDateTime.hour, _fromDateTime.minute);
      _toDateTime = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, _toDateTime.hour, _toDateTime.minute);
    });
  }

  Future<void> _selectTime(BuildContext context, bool isFrom) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isFrom ? _fromDateTime : _toDateTime),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDateTime = DateTime(
            _fromDateTime.year,
            _fromDateTime.month,
            _fromDateTime.day,
            picked.hour,
            picked.minute,
          );
        } else {
          _toDateTime = DateTime(
            _toDateTime.year,
            _toDateTime.month,
            _toDateTime.day,
            picked.hour,
            picked.minute,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
        title: const Text(
          'Add Reminder',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Save logic here
              Navigator.pop(context);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.orange, fontSize: 16),
            ),
          ),
        ],
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), // Ensure smooth scrolling in both directions
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Input
            const TextField(
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(fontSize: 20),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            Divider(
              color: Colors.grey[300],
              thickness: 0.5,
              height: 0,
            ),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(fontSize: 16),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              maxLines: 1,
            ),
            Divider(
              color: Colors.grey[300],
              thickness: 0.5,
              height: 0,
            ),
            const SizedBox(height: 16),
            // Calendar Picker
            const Center(
              child: Text(
                'Select Date & Time',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            _buildCalendarPicker(),
            const SizedBox(height: 16),
            Divider(
              color: Colors.grey[300],
              thickness: 0.5,
              height: 0,
            ),
            const SizedBox(height: 16),
            // Important Checkbox
            Row(
              children: [
                const Text('Important'),
                const Spacer(),
                Checkbox(
                  value: _isImportant,
                  activeColor: Colors.orange,
                  onChanged: (value) {
                    setState(() {
                      _isImportant = value ?? false;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              color: Colors.grey[300],
              thickness: 0.5,
              height: 0,
            ),
            const SizedBox(height: 16),
            // Schedule Section
            const Text(
              'Schedule',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 40,
                  child: Text(
                    'From',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDateTimePicker('From', _fromDateTime, true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 40,
                  child: Text(
                    'To',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDateTimePicker('To', _toDateTime, false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              color: Colors.grey[300],
              thickness: 0.5,
              height: 0,
            ),
            const SizedBox(height: 16),
            // Sound Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sound',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                ),
                DropdownButton<String>(
                  value: 'Opening(default)',
                  items: ['Opening(default)', 'Sound 1', 'Sound 2', 'Sound 3']
                      .map((sound) => DropdownMenuItem(
                    value: sound,
                    child: Text(
                      sound,
                      style: const TextStyle(fontWeight: FontWeight.w400),
                    ),
                  ))
                      .toList(),
                  onChanged: (value) {},
                  underline: const SizedBox(),
                  icon: const Icon(Icons.chevron_right, color: Colors.grey),
                  isDense: true,
                  alignment: Alignment.centerRight,
                  style: const TextStyle(fontWeight: FontWeight.w400, color: Colors.black),
                  selectedItemBuilder: (BuildContext context) {
                    return ['Opening(default)', 'Sound 1', 'Sound 2', 'Sound 3'].map((sound) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          sound,
                          style: const TextStyle(fontWeight: FontWeight.w400),
                        ),
                      );
                    }).toList();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarPicker() {
    return SizedBox(
      height: 350, // Fixed height to ensure the calendar fits well in the scroll view
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: _onDaySelected,
        calendarFormat: CalendarFormat.month,
        availableGestures: AvailableGestures.none, // Disable calendar's internal gestures
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker(String label, DateTime dateTime, bool isFrom) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Date picker logic (already handled by TableCalendar)
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[100],
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              '${dateTime.day} ${_getMonthName(dateTime.month)}, ${dateTime.year}',
              style: const TextStyle(color: Colors.orange, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => _selectTime(context, isFrom),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[100],
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour >= 12 ? 'PM' : 'AM'}',
            style: const TextStyle(color: Colors.orange,fontSize: 14),
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}