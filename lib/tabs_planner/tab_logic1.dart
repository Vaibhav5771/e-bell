import 'package:flutter/material.dart';

class TabLogic {
  int _selectedTabIndex = 0;

  int get selectedTabIndex => _selectedTabIndex;

  void setSelectedTab(int index) {
    _selectedTabIndex = index;
  }

  Widget buildTab({
    required BuildContext context,
    required String text,
    required int index,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: _selectedTabIndex == index ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: _selectedTabIndex == index ? Colors.black : Colors.black54,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}