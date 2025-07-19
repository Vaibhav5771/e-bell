import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/theme_state.dart';


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
        title: const Text('Help & Privacy'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Help',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const Divider(height: 32),
              const Text(
                'Privacy Policy',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const Divider(height: 32),
              const Text(
                'Contact Support',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'For further assistance, please contact our support team at support@iogenies.com or call +1-800-555-1234.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}