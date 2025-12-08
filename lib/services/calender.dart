class CalendarLogic {
  DateTime _focusedDay;
  DateTime _selectedDay;
  final DateTime _firstDay;
  final DateTime _lastDay;

  CalendarLogic()
      : _focusedDay = DateTime.now(),
        _selectedDay = DateTime.now(),
        _firstDay = DateTime.now().subtract(const Duration(days: 365 * 5)), // 5 years in the past
        _lastDay = DateTime.now().add(const Duration(days: 365 * 5)); // 5 years in the future

  DateTime get focusedDay => _focusedDay;
  DateTime get selectedDay => _selectedDay;
  DateTime get firstDay => _firstDay;
  DateTime get lastDay => _lastDay;

  void setFocusedDay(DateTime day) {
    _focusedDay = day;
  }

  void setSelectedDay(DateTime day) {
    _selectedDay = day;
  }
}