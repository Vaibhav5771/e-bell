import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../authentication/auth_service.dart';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final userData = await _authService.getUserData(user.uid);
        if (mounted) {
          setState(() {
            _userData = userData;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'No user is currently logged in';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to fetch user data: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    print('AccountScreen: Using color ${themeProvider.selectedColor}');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.selectedColor),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Account',
          style: AppTextStyles.heading,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
          child: Text(
            _error!,
            style: AppTextStyles.body,
          ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text(
            //   'Name',
            //   style: AppTextStyles.link.copyWith(color: Colors.grey),
            // ),
            // const SizedBox(height: 4),
            // Text(
            //   _userData?['username'] ?? 'N/A',
            //   style: AppTextStyles.body,
            // ),
            // const Divider(height: 32),
            // Text(
            //   'Contact',
            //   style: AppTextStyles.link.copyWith(color: Colors.grey),
            // ),
            // const SizedBox(height: 4),
            // Text(
            //   _userData?['contact'] ?? '1234567890',
            //   style: AppTextStyles.body,
            // ),
            // const Divider(height: 32),
            // Text(
            //   'Email',
            //   style: AppTextStyles.link.copyWith(color: Colors.grey),
            // ),
            // const SizedBox(height: 4),
            // Text(
            //   _userData?['email'] ?? 'N/A',
            //   style: AppTextStyles.body,
            // ),
            // const Divider(height: 32),
            Text(
              'SSID',
              style: AppTextStyles.link.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              _userData?['ssid'] ?? 'IoGen_Speaker',
              style: AppTextStyles.body,
            ),
            const Divider(height: 32),
            Text(
              'Device Password',
              style: AppTextStyles.link.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              _userData?['devicePassword'] ?? '12345678',
              style: AppTextStyles.body,
            ),
            const Divider(height: 32),
            // Text(
            //   'DOB',
            //   style: AppTextStyles.link.copyWith(color: Colors.grey),
            // ),
            // const SizedBox(height: 4),
            // Text(
            //   _userData?['dob'] ?? '13-05-25',
            //   style: AppTextStyles.body,
            // ),
            // const Divider(height: 32),
            // Text(
            //   'Address',
            //   style: AppTextStyles.link.copyWith(color: Colors.grey),
            // ),
            // const SizedBox(height: 4),
            // Text(
            //   _userData?['address'] ?? 'Lorem Ipsum Lorem Ipsum Lorem Ipsum',
            //   style: AppTextStyles.body,
            // ),
          ],
        ),
      ),
    );
  }
}