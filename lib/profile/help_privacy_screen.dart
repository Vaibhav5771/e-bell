import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';

class HelpPrivacyScreen extends StatefulWidget {
  const HelpPrivacyScreen({super.key});

  @override
  State<HelpPrivacyScreen> createState() => _HelpPrivacyScreenState();
}

class _HelpPrivacyScreenState extends State<HelpPrivacyScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    print('HelpPrivacyScreen: Using color ${themeProvider.selectedColor}');
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.selectedColor),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Help & Privacy',
          style: AppTextStyles.heading,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Help',
                style: AppTextStyles.link.copyWith(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
                style: AppTextStyles.link.copyWith(height: 1.5),
              ),
              const Divider(height: 32),
              Text(
                'Privacy Policy',
                style: AppTextStyles.link.copyWith(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                'Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
                style: AppTextStyles.link.copyWith(height: 1.5),
              ),
              const Divider(height: 32),
              Text(
                'Contact Support',
                style: AppTextStyles.link.copyWith(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                'For further assistance, please contact our support team at support@iogenies.com or call +1-800-555-1234.',
                style: AppTextStyles.link.copyWith(height: 1.5),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}