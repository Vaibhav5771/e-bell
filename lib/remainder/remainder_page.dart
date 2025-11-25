import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/services.dart';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedFromDay;
  DateTime? _selectedToDay;
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _period = TimeOfDay.now().hour < 12 ? 'AM' : 'PM';
  String _title = '';
  String _description = '';
  bool _isImportant = false;
  String _soundOption = '';
  List<String> _soundOptions = [];
  bool isLoading = false;
  bool _showFromCalendar = false;
  bool _showToCalendar = false;
  bool _showTimePicker = false;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _periodController;
  bool _isRepeatEnabled = false;
  List<bool> _selectedDays = List.filled(7, false);

  @override
  void initState() {
    super.initState();
    // Initialize selectedFromDay and selectedToDay to today by default
    final now = DateTime.now();
    _selectedFromDay = DateTime(now.year, now.month, now.day);
    _selectedToDay = DateTime(now.year, now.month, now.day);
    _focusedDay = DateTime(now.year, now.month, now.day);

    final int hour = _selectedTime.hourOfPeriod == 0
        ? 11
        : _selectedTime.hourOfPeriod - 1;
    _hourController = FixedExtentScrollController(initialItem: hour);
    _minuteController = FixedExtentScrollController(
      initialItem: _selectedTime.minute,
    );
    _periodController = FixedExtentScrollController(
      initialItem: _period == 'AM' ? 0 : 1,
    );

    _loadUploadedFiles();
  }

  Future<void> _loadUploadedFiles() async {
    final bellService = BellService();
    final soundFiles = await bellService.fetchSoundFiles(context);

    setState(() {
      _soundOptions = soundFiles;
      _soundOption = _soundOptions.isNotEmpty ? _soundOptions[0] : '';
    });
  }

  void _onFromDaySelected(DateTime selectedDay, DateTime focusedDay) {
    // Prevent selecting past dates: enforce minimum = today
    final today = DateTime.now();
    final minSelectable = DateTime(today.year, today.month, today.day);
    DateTime normalized = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    if (normalized.isBefore(minSelectable)) {
      normalized = minSelectable;
    }

    setState(() {
      _selectedFromDay = normalized;
      // ensure to-date is not before from-date
      if (_selectedToDay != null &&
          _selectedToDay!.isBefore(_selectedFromDay!)) {
        _selectedToDay = _selectedFromDay;
      }
      _focusedDay = focusedDay;
      _showFromCalendar = false; // Close calendar after selection

      // If repeat is enabled, unselect any days outside new allowed range
      if (_isRepeatEnabled) {
        _enforceAllowedRepeatDays();
      }
    });
  }

  void _onToDaySelected(DateTime selectedDay, DateTime focusedDay) {
    // Prevent selecting past dates: enforce minimum = today
    final today = DateTime.now();
    final minSelectable = DateTime(today.year, today.month, today.day);
    DateTime normalized = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    if (normalized.isBefore(minSelectable)) {
      normalized = minSelectable;
    }

    setState(() {
      _selectedToDay = normalized;
      // if from-date is after to-date, move from-date to to-date
      if (_selectedFromDay != null &&
          _selectedFromDay!.isAfter(_selectedToDay!)) {
        _selectedFromDay = _selectedToDay;
      }
      _focusedDay = focusedDay;
      _showToCalendar = false; // Close calendar after selection

      // If repeat is enabled, unselect any days outside new allowed range
      if (_isRepeatEnabled) {
        _enforceAllowedRepeatDays();
      }
    });
  }

  // Convert selectedDays indices [0..6] where 0=Sun..6=Sat
  // Returns allowed weekday indices using same mapping 0..6
  List<int> _getAllowedWeekdays() {
    if (_selectedFromDay == null || _selectedToDay == null)
      return List.generate(7, (i) => i);

    DateTime start = DateTime(
      _selectedFromDay!.year,
      _selectedFromDay!.month,
      _selectedFromDay!.day,
    );
    DateTime end = DateTime(
      _selectedToDay!.year,
      _selectedToDay!.month,
      _selectedToDay!.day,
    );

    // Ensure start <= end
    if (start.isAfter(end)) {
      final tmp = start;
      start = end;
      end = tmp;
    }

    final allowed = <int>{};
    DateTime cursor = start;
    while (!cursor.isAfter(end)) {
      // DateTime.weekday: 1=Mon .. 7=Sun. Convert to mapping 0=Sun..6=Sat
      final mappingIndex = cursor.weekday % 7; // Sun -> 0, Mon ->1, ..., Sat->6
      allowed.add(mappingIndex);
      cursor = cursor.add(const Duration(days: 1));
    }
    final allowedList = allowed.toList()..sort();
    return allowedList;
  }

  void _enforceAllowedRepeatDays() {
    final allowed = _getAllowedWeekdays();
    bool changed = false;
    for (int i = 0; i < _selectedDays.length; i++) {
      if (_selectedDays[i] && !allowed.contains(i)) {
        _selectedDays[i] = false;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  int _calculateWeekBitmask() {
    const List<int> dayBitmasks = [
      128,
      2,
      4,
      8,
      16,
      32,
      64,
    ]; // [Sun, Mon, Tue, Wed, Thu, Fri, Sat]
    int week = 0;
    final allowed = _getAllowedWeekdays();
    for (int i = 0; i < _selectedDays.length; i++) {
      if (_selectedDays[i] && allowed.contains(i)) {
        week |= dayBitmasks[i];
      }
    }
    return week == 0
        ? 254
        : week; // keep existing behavior: 254 means "no specific week bitmask"
  }

  Future<bool> _verifyReminder(
      String soundOption,
      int hr,
      int mn,
      int sEpoch,
      int eEpoch,
      int week,
      int alarmType,
      ) async {
    try {
      final response = await http
          .get(Uri.parse('http://192.168.2.1/songs'))
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Verification request timed out');
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['Data'] as List<dynamic>?;

        if (data != null && data.isNotEmpty) {
          final filesData = data[0]['files'] as List<dynamic>?;
          if (filesData != null) {
            final filenames = filesData
                .map((file) => (file as List<dynamic>)[0] as String)
                .toList();
            return filenames.contains(soundOption);
          }
        }
        return false;
      } else {
        return false;
      }
    } catch (e) {
      print('Verification error: $e');
      return false;
    }
  }

  Future<void> _saveReminder() async {
    if (_title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Title is required', style: AppTextStyles.body)),
      );
      return;
    }

    if (_selectedFromDay == null || _selectedToDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select both From and To dates',
            style: AppTextStyles.body,
          ),
        ),
      );
      return;
    }

    if (_soundOptions.isEmpty || _soundOption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No sound files available. Please check the device connection.',
            style: AppTextStyles.body,
          ),
        ),
      );
      return;
    }

    // IST offset (5 hours 30 minutes in seconds)
    const int IST_OFFSET = 5 * 3600 + 30 * 60;

    // Start epoch uses selected FROM date + selected time (Option B)
    final reminderFromDateTime = DateTime(
      _selectedFromDay!.year,
      _selectedFromDay!.month,
      _selectedFromDay!.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final reminderToDateTime = DateTime(
      _selectedToDay!.year,
      _selectedToDay!.month,
      _selectedToDay!.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    setState(() => isLoading = true);

    int hr = _selectedTime.hour;
    int mn = _selectedTime.minute;

    // Convert to IST epoch timestamps
    int sEpoch =
        (reminderFromDateTime.millisecondsSinceEpoch / 1000).floor() -
            IST_OFFSET;
    int eEpoch =
        (reminderToDateTime.millisecondsSinceEpoch / 1000).floor() -
            IST_OFFSET +
            86399; // Add 23:59:59

    int active = 1;
    int week = _isRepeatEnabled ? _calculateWeekBitmask() : 254;
    int alarmType = 2;

    final data = '$hr,$mn,$sEpoch,$eEpoch,$active,$week,$alarmType';
    final url = 'http://192.168.2.1/settime/$_soundOption';
    final curlCommand = 'curl -X POST $url -d "\$data"';

    print('Sending POST request to: $url');
    print('Data: $data');
    print('Sound file: $_soundOption');

    bool scheduled = false;
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'text/plain'},
        body: data,
      );
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      scheduled = response.statusCode == 200;

      if (scheduled) {
        bool verified = await _verifyReminder(
          _soundOption,
          hr,
          mn,
          sEpoch,
          eEpoch,
          week,
          alarmType,
        );
        if (verified) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Reminder set for ${reminderFromDateTime} with $_soundOption (Verified)\n$curlCommand',
                style: AppTextStyles.body,
              ),
              duration: const Duration(seconds: 5),
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ Reminder set but verification failed for $_soundOption\n$curlCommand',
                style: AppTextStyles.body,
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Failed to set reminder: ${response.statusCode} - ${response.body}',
              style: AppTextStyles.body,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error sending request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Error setting reminder: $e',
            style: AppTextStyles.body,
          ),
        ),
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select Date';
    return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  Widget _buildDaysSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final dayAbbreviations = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
    final allowedDays = _getAllowedWeekdays();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (index) {
          final isAllowed = allowedDays.contains(index);
          return GestureDetector(
            onTap: isAllowed
                ? () {
              setState(() {
                _selectedDays[index] = !_selectedDays[index];
              });
            }
                : null,
            child: Opacity(
              opacity: isAllowed ? 1.0 : 0.35,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _selectedDays[index] && isAllowed
                      ? themeProvider.selectedColor
                      : Colors.transparent,
                  border: Border.all(
                    color: _selectedDays[index] && isAllowed
                        ? themeProvider.selectedColor
                        : (isAllowed ? Colors.grey : Colors.grey.shade300),
                  ),
                ),
                child: Center(
                  child: Text(
                    dayAbbreviations[index],
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _selectedDays[index] && isAllowed
                          ? Colors.white
                          : (isAllowed ? Colors.black : Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Only render title if it's not empty. This allows sections without titles.
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                title,
                style: AppTextStyles.subheading.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Center(
          child: Text('Add Reminder', style: AppTextStyles.heading),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.check,
              color: _soundOptions.isEmpty
                  ? Colors.grey
                  : themeProvider.selectedColor,
            ),
            onPressed: _soundOptions.isEmpty ? null : _saveReminder,
          ),
        ],
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
            // Box 1: Title & Description
            _buildSectionContainer(
              title: 'Info',
              children: [
                TextField(
                  onChanged: (value) => setState(() => _title = value),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 1,
                    ),
                  ),
                ),
                _buildDivider(),
                TextField(
                  onChanged: (value) =>
                      setState(() => _description = value),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: AppTextStyles.body,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  maxLines: 1,
                ),
              ],
            ),

            // Box 2: Schedule (Date & Time)
            _buildSectionContainer(
              title: 'Schedule',
              children: [
                // Date Selection - Right aligned layout
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    children: [
                      // From Date Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment
                            .spaceBetween, // This pushes items to edges
                        children: [
                          SizedBox(
                            width: 60, // Fixed width for "From" label
                            child: Text(
                              'From',
                              style: AppTextStyles.body.copyWith(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            width:
                            180, // Fixed width for the date selection box
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showFromCalendar = !_showFromCalendar;
                                  _showToCalendar = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDate(_selectedFromDay),
                                      style: AppTextStyles.body.copyWith(
                                        fontSize: 14,
                                      ),
                                    ),
                                    Icon(
                                      _showFromCalendar
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Calendar for From date
                      if (_showFromCalendar)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: _buildCalendarPicker(
                            themeProvider,
                            true,
                          ),
                        ),

                      const SizedBox(height: 12),

                      // To Date Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment
                            .spaceBetween, // This pushes items to edges
                        children: [
                          SizedBox(
                            width: 60, // Fixed width for "To" label
                            child: Text(
                              'To',
                              style: AppTextStyles.body.copyWith(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            width:
                            180, // Fixed width for the date selection box
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showToCalendar = !_showToCalendar;
                                  _showFromCalendar = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDate(_selectedToDay),
                                      style: AppTextStyles.body.copyWith(
                                        fontSize: 14,
                                      ),
                                    ),
                                    Icon(
                                      _showToCalendar
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Calendar for To date
                      if (_showToCalendar)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: _buildCalendarPicker(
                            themeProvider,
                            false,
                          ),
                        ),
                    ],
                  ),
                ),

                // Time Selection - Right aligned layout
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment
                        .spaceBetween, // This pushes items to edges
                    children: [
                      SizedBox(
                        width: 60, // Fixed width for "Time" label
                        child: Text(
                          'Time',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        width:
                        180, // Fixed width for the time selection box
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showTimePicker = !_showTimePicker;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.shade300,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_selectedTime.hourOfPeriod == 0 ? 12 : _selectedTime.hourOfPeriod}:${_selectedTime.minute.toString().padLeft(2, '0')} $_period',
                                  style: AppTextStyles.body.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                                Icon(
                                  _showTimePicker
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Time Picker
                if (_showTimePicker)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildTimePicker(isSmallScreen, themeProvider),
                  ),

                const SizedBox(height: 8),
              ],
            ),

            // Box 3: Other Options
            // Previously used _buildSectionContainer(title: '', ...)
            // Now we intentionally render a container without any title area.
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        } else {
                          // When enabling repeat, ensure currently selected days are within allowed range
                          _enforceAllowedRepeatDays();
                        }
                      });
                    },
                  ),
                  if (_isRepeatEnabled) _buildDaysSelector(),
                  _buildDivider(),
                  _buildOptionTile(
                    context,
                    title: 'Sound',
                    value: _soundOption.isEmpty
                        ? 'Select a sound'
                        : _soundOption,
                    onTap: _soundOptions.isEmpty
                        ? null
                        : _selectSoundOption,
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

  Widget _buildCalendarPicker(
      ThemeProvider themeProvider,
      bool isFromCalendar,
      ) {
    final today = DateTime.now();
    final firstDay = DateTime(today.year, today.month, today.day);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: firstDay,
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) =>
            isSameDay(isFromCalendar ? _selectedFromDay : _selectedToDay, day),
        onDaySelected: isFromCalendar ? _onFromDaySelected : _onToDaySelected,
        calendarFormat: CalendarFormat.month,
        availableGestures: AvailableGestures.none,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: AppTextStyles.subheading.copyWith(
            fontWeight: FontWeight.bold,
          ),
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
          outsideDaysVisible: false,
        ),
      ),
    );
  }

  Widget _buildTimePicker(bool isSmallScreen, ThemeProvider themeProvider) {
    return Container(
      // Changed background to white as requested
      height: isSmallScreen ? 200.0 : 240.0,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
                        color:
                        displayHour ==
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
          SizedBox(
            width: isSmallScreen ? 80 : 100,
            child: ListWheelScrollView(
              itemExtent: 60,
              perspective: 0.005,
              diameterRatio: 1.2,
              physics: const FixedExtentScrollPhysics(),
              controller: _periodController,
              onSelectedItemChanged: (index) {
                setState(() {
                  _period = index == 0 ? 'AM' : 'PM';
                  int currentHour = _selectedTime.hour;
                  if (_period == 'AM' && currentHour >= 12) {
                    _selectedTime = _selectedTime.replacing(
                      hour: currentHour - 12,
                    );
                  } else if (_period == 'PM' && currentHour < 12) {
                    _selectedTime = _selectedTime.replacing(
                      hour: currentHour + 12,
                    );
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
    );
  }

  void _selectSoundOption() {
    if (_soundOptions.isEmpty) {
      print('No sound options available');
      return;
    }
    print('Available sound options: $_soundOptions');
    print('Currently selected: $_soundOption');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _buildOptionSelectionSheet(
          title: 'Sound',
          options: _soundOptions,
          selectedOption: _soundOption,
          onSelect: (value) {
            print('Selected sound: $value');
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
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: AppTextStyles.subheading.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                return ListTile(
                  title: Text(option, style: AppTextStyles.body),
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
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
          Text(
            value!,
            style: AppTextStyles.body.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
  }
}