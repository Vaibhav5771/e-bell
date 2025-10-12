import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/services.dart';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  TimeOfDay _selectedTime = TimeOfDay.now();
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
  List<bool> _selectedDays = List.filled(7, false);

  @override
  void initState() {
    super.initState();
    _loadUploadedFiles();

    int hourIndex = _selectedTime.hourOfPeriod - 1;
    hourIndex = hourIndex == -1 ? 11 : hourIndex;

    _hourController = FixedExtentScrollController(initialItem: hourIndex);
    _minuteController =
        FixedExtentScrollController(initialItem: _selectedTime.minute);
    _periodController = FixedExtentScrollController(
        initialItem: _selectedTime.period == DayPeriod.am ? 0 : 1);
  }

  Future<void> _loadUploadedFiles() async {
    final bellService = BellService();
    final soundFiles = await bellService.fetchSoundFiles(context);

    setState(() {
      _soundOptions = soundFiles;
      _soundOption = _soundOptions.isNotEmpty ? _soundOptions[0] : '';
    });
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
      thickness: 0.8,
      color: Colors.grey[200],
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildDaysSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final dayAbbreviations = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 20),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 15,
        children: List.generate(7, (index) {
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDays[index] = !_selectedDays[index];
              });
            },
            child: Container(
              width: 38,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _selectedDays[index]
                    ? themeProvider.selectedColor
                    : Colors.white,
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

  Future<void> _saveAlarm() async {
    String soundFile = _soundOption;
    int hr = _selectedTime.hour;
    int mn = _selectedTime.minute;
    int week;
    int sEpoch = 0;
    int eEpoch = 0;
    int active = 1;
    int alarmType = 1;

    if (_isRepeatEnabled) {
      const List<int> dayBitmasks = [128, 2, 4, 8, 16, 32, 64];
      week = 0;
      for (int i = 0; i < _selectedDays.length; i++) {
        if (_selectedDays[i]) week |= dayBitmasks[i];
      }
      week = week == 0 ? 254 : week;
    } else {
      week = 254;
      final now = DateTime.now();
      DateTime alarmDateTime = DateTime(now.year, now.month, now.day, hr, mn);
      if (alarmDateTime.isBefore(now)) {
        alarmDateTime = alarmDateTime.add(const Duration(days: 1));
      }
      hr = alarmDateTime.hour;
      mn = alarmDateTime.minute;
    }

    String data = '$hr,$mn,$sEpoch,$eEpoch,$active,$week,$alarmType';
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
          const SnackBar(content: Text('✅ Alarm set successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }

    Navigator.pop(context);
  }

  void _selectSoundOption() {
    if (_soundOptions.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text('Select Sound',
                  style: AppTextStyles.subheading
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Divider(height: 1, color: Colors.grey[200]),
              Expanded(
                child: ListView.builder(
                  itemCount: _soundOptions.length,
                  itemBuilder: (context, index) {
                    final option = _soundOptions[index];
                    return ListTile(
                      title: Text(option, style: AppTextStyles.body),
                      trailing: option == _soundOption
                          ? Icon(Icons.check,
                          color: themeProvider.selectedColor)
                          : null,
                      onTap: () {
                        setState(() => _soundOption = option);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add Alarm'),
        centerTitle: true,
        titleTextStyle:
        AppTextStyles.heading.copyWith(fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: Icon(Icons.check,
                color: _soundOptions.isEmpty
                    ? Colors.grey
                    : themeProvider.selectedColor),
            onPressed: _soundOptions.isEmpty ? null : _saveAlarm,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Time Selector
              _buildCard(
                child: SizedBox(
                  height: 220,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildWheel(
                          controller: _hourController,
                          count: 12,
                          onChanged: (index) {
                            int hour = (index % 12) + 1;
                            setState(() {
                              _selectedTime = _selectedTime.replacing(
                                hour: _period == 'AM'
                                    ? (hour == 12 ? 0 : hour)
                                    : (hour == 12 ? 12 : hour + 12),
                              );
                            });
                          },
                          selectedValue: _selectedTime.hourOfPeriod == 0
                              ? 12
                              : _selectedTime.hourOfPeriod,
                          displayFormat: (i) =>
                              (i + 1).toString().padLeft(2, '0')),
                      _buildWheel(
                          controller: _minuteController,
                          count: 60,
                          onChanged: (index) {
                            setState(() {
                              _selectedTime = _selectedTime.replacing(
                                  minute: index % 60);
                            });
                          },
                          selectedValue: _selectedTime.minute,
                          displayFormat: (i) =>
                              i.toString().padLeft(2, '0')),
                      _buildPeriodWheel(),
                    ],
                  ),
                ),
              ),

              // Alarm Details
              _buildCard(
                child: Column(
                  children: [
                    _buildOptionTile(
                      title: 'Repeat',
                      isSwitch: true,
                      switchValue: _isRepeatEnabled,
                      onSwitchChanged: (v) {
                        setState(() {
                          _isRepeatEnabled = v;
                          if (!v) {
                            _selectedDays = List.filled(7, false);
                          }
                        });
                      },
                    ),
                    if (_isRepeatEnabled) _buildDaysSelector(),
                    _buildDivider(),
                    _buildOptionTile(
                      title: 'Label',
                      isTextField: true,
                      value: _alarmLabel,
                      onChanged: (v) => setState(() => _alarmLabel = v),
                    ),
                    _buildDivider(),
                    _buildOptionTile(
                      title: 'Sound',
                      value: _soundOption.isEmpty
                          ? 'Select a sound'
                          : _soundOption,
                      onTap: _soundOptions.isEmpty
                          ? null
                          : _selectSoundOption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int count,
    required Function(int) onChanged,
    required int selectedValue,
    required String Function(int) displayFormat,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return SizedBox(
      width: 90,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 50,
        perspective: 0.005,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          onChanged(index);
          setState(() {}); // force rebuild to update color
        },
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, i) {
            final displayText = displayFormat(i % count);

            final isSelected = count == 12
                ? ((i % count + 1) ==
                (_selectedTime.hourOfPeriod == 0
                    ? 12
                    : _selectedTime.hourOfPeriod))
                : i % count == _selectedTime.minute;

            return Center(
              child: Text(
                displayText,
                style: AppTextStyles.heading.copyWith(
                  fontSize: 32,
                  color:
                  isSelected ? themeProvider.selectedColor : Colors.black,
                ),
              ),
            );
          },
          childCount: count,
        ),
      ),
    );
  }

  Widget _buildPeriodWheel() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return SizedBox(
      width: 80,
      child: ListWheelScrollView(
        controller: _periodController,
        itemExtent: 50,
        physics: const FixedExtentScrollPhysics(),
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
          final isSelected = _period == period;
          return Center(
            child: Text(
              period,
              style: AppTextStyles.heading.copyWith(
                fontSize: 32,
                color: isSelected ? themeProvider.selectedColor : Colors.black,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOptionTile({
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
                  hintStyle: AppTextStyles.body
                      .copyWith(color: Colors.grey[600]),
                ),
                onChanged: onChanged,
              ),
            )
          else
            Text(
              value!,
              style: AppTextStyles.body.copyWith(color: Colors.grey[600]),
            ),
          if (!isTextField && !isSwitch)
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}