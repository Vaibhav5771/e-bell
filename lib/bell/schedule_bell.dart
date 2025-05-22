import 'package:flutter/material.dart';

class BellConfigurationScreen extends StatefulWidget {
  const BellConfigurationScreen({super.key});

  @override
  _BellConfigurationScreenState createState() => _BellConfigurationScreenState();
}

class _BellConfigurationScreenState extends State<BellConfigurationScreen> {
  DateTime _fromDateTime = DateTime(2024, 6, 10, 10, 0); // Default as per image
  DateTime _toDateTime = DateTime(2024, 6, 10, 10, 0); // Default as per image
  bool _isAllTime = false;

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
      backgroundColor: Colors.white,
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
          'Bell Configuration',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () {
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sound Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sound',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                ),
                Divider(
                  color: Colors.grey[300],
                  thickness: 0.5,
                  height: 0,
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
            const SizedBox(height: 16),
            Divider(
              color: Colors.grey[300],
              thickness: 0.5,
              height: 0,
            ),
            const SizedBox(height: 16),
            // Repeat Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Repeat',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                ),
                DropdownButton<String>(
                  value: 'Never',
                  items: ['Never', 'Daily', 'Weekly', 'Monthly']
                      .map((repeat) => DropdownMenuItem(
                    value: repeat,
                    child: Text(
                      repeat,
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
                    return ['Never', 'Daily', 'Weekly', 'Monthly'].map((repeat) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          repeat,
                          style: const TextStyle(fontWeight: FontWeight.w400),
                        ),
                      );
                    }).toList();
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
            // Label Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Label',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                ),
                DropdownButton<String>(
                  value: '',
                  items: ['']
                      .map((label) => DropdownMenuItem(
                    value: label,
                    child: const Text(''),
                  ))
                      .toList(),
                  onChanged: (value) {},
                  underline: const SizedBox(),
                  icon: const Icon(Icons.chevron_right, color: Colors.grey),
                  isDense: true,
                  alignment: Alignment.centerRight,
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

            // All Time Checkbox
            Row(
              children: [
                const Text(
                  'All time',
                  style: TextStyle(fontSize: 16),
                ),
                const Spacer(),
                Checkbox(
                  value: _isAllTime,
                  activeColor: Colors.orange,
                  onChanged: (value) {
                    setState(() {
                      _isAllTime = value ?? false;
                    });
                  },
                ),
              ],
            ),
            Divider(
              color: Colors.grey[300],
              thickness: 0.5,
              height: 0,
            ),
          ],
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
              // Date picker logic can be added here if needed
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
            style: const TextStyle(color: Colors.orange, fontSize: 14),
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

