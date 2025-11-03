// widgets/home/navigation_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:e_bell/utils/app_text_styles.dart';
import 'package:e_bell/utils/theme_state.dart';

class CustomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final ThemeProvider themeProvider;

  const CustomNavigationBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.themeProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 75,
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.white,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 0,
        unselectedFontSize: 0,
        items: [
          BottomNavigationBarItem(
            icon: _buildNavItem(
              isSelected: currentIndex == 0,
              selectedIcon: Icons.calendar_month,
              unselectedIcon: Icons.calendar_month_outlined,
              label: "Planner",
              color: themeProvider.selectedColor,
            ),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: _buildNavItem(
              isSelected: currentIndex == 1,
              selectedIcon: Icons.music_note,
              unselectedIcon: Icons.music_note_outlined,
              label: "Library",
              color: themeProvider.selectedColor,
            ),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: _buildNavItem(
              isSelected: currentIndex == 2,
              selectedIcon: Icons.person,
              unselectedIcon: Icons.person_outline,
              label: "Profile",
              color: themeProvider.selectedColor,
            ),
            label: "",
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required bool isSelected,
    required IconData selectedIcon,
    required IconData unselectedIcon,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      height: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? selectedIcon : unselectedIcon,
            color: isSelected ? color : Colors.grey,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.small.copyWith(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? color : Colors.grey,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}