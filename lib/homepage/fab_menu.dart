// widgets/home/fab_menu.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:e_bell/utils/app_text_styles.dart';
import 'package:e_bell/utils/theme_state.dart';
import 'package:e_bell/pages/namaz_Sunrise.dart';
import '../alarm/alarm_page.dart';
import '../remainder/remainder_page.dart';

class FabMenu extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;

  const FabMenu({
    Key? key,
    required this.isOpen,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isOpen) return const SizedBox.shrink();

    return Stack(
      children: [
        // 1️⃣ Transparent overlay to catch outside taps
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
        ),

        // 2️⃣ The actual FAB menu container
        Positioned(
          bottom: 80,
          right: 16,
          child: GestureDetector(
            onTap: () {
              // Prevent tap from propagating and closing the menu
            },
            child: Container(
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildFabOption('Reminder', true, context),
                  _buildFabOption('Alarm', false, context),
                  _buildFabOption('Regional Planner', false, context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFabOption(String title, bool isChecked, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          onClose();
          switch (title) {
            case 'Alarm':
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AlarmPage()),
              );
              break;
            case 'Reminder':
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReminderPage()),
              );
              break;
            case 'Regional Planner':
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReligiousAlarms()),
              );
              break;
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: themeProvider.selectedColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 16),
              (title == 'Regional Planner')
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Regional',
                    style: AppTextStyles.body
                        .copyWith(color: Colors.black87),
                  ),
                  Text(
                    'Planner',
                    style: AppTextStyles.body
                        .copyWith(color: Colors.black87),
                  ),
                ],
              )
                  : Text(
                title,
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
