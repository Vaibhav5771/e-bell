import 'package:e_bell/utils/quickalert.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this
import '../authentication/auth_service.dart';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';
import 'devices_screen.dart';
import 'app_setting.dart';
import 'device_setting.dart';
import 'app_info.dart';
import 'help_privacy_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const List<Map<String, dynamic>> _items = [
    {'icon': Icons.device_hub, 'title': 'Added Devices', 'screen': AccountScreen()},
    {'icon': Icons.settings, 'title': 'Device Setting', 'screen': DeviceSettingScreen()},
    {'icon': Icons.tune, 'title': 'App Setting', 'screen': AppSettingScreen()},
    {'icon': Icons.help_outline, 'title': 'Help & Privacy', 'screen': HelpPrivacyScreen()},
    {'icon': Icons.info_outline, 'title': 'App Info', 'screen': AppInfoScreen()},
  ];

  final AuthService _authService = AuthService();
  Map<String, String>? _userData; // Store username & email
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Load user data from SharedPreferences or Firebase
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if data is already stored
    final storedUsername = prefs.getString('username');
    final storedEmail = prefs.getString('email');

    if (storedUsername != null && storedEmail != null) {
      // Use stored data
      setState(() {
        _userData = {'username': storedUsername, 'email': storedEmail};
        _isLoading = false;
      });
    } else {
      // Fetch from Firebase
      await _fetchUserData();
    }
  }

  /// Fetch from Firebase and store locally
  Future<void> _fetchUserData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final data = await _authService.getUserData(user.uid);
        if (mounted) {
          setState(() {
            _userData = {
              'username': data?['username'] ?? 'Unknown User',
              'email': data?['email'] ?? 'user@example.com',
            };
            _isLoading = false;
          });
        }

        // Store in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', _userData!['username']!);
        await prefs.setString('email', _userData!['email']!);
      } else {
        if (mounted) {
          setState(() {
            _error = 'No user logged in';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load user: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Logout clears shared preferences
  Future<void> _handleLogout(BuildContext context) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    bool confirmLogout = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Text(
              "Do you really want to logout?",
              style: AppTextStyles.subheading.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Divider(height: 1, thickness: 0.5, color: Colors.grey[400]),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text("Cancel", style: AppTextStyles.link.copyWith(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text("Confirm",
                      style: AppTextStyles.link.copyWith(color: themeProvider.selectedColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmLogout == true) {
      try {
        await AuthService().signOut(context);

        // Clear stored user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('username');
        await prefs.remove('email');

        AppAlert.success(
          context,
          text: 'Logged out successfully!',
        );
      } catch (e) {
        if (mounted) {
          AppAlert.error(
            context,
            text: 'Logout failed: $e',
          );
        }
      }
    }
  }

  Widget _buildListTile(BuildContext context,
      {required IconData icon, required String title, required VoidCallback onTap}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: themeProvider.selectedColor.withOpacity(0.2),
          ),
          child: CircleAvatar(
            backgroundColor: themeProvider.selectedColor,
            child: Icon(icon, color: themeProvider.textColor, size: 24),
          ),
        ),
        title: Text(title, style: AppTextStyles.body.copyWith(color: Colors.black87)),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: Container(
        color: Colors.grey[100],
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Padding(
                padding: const EdgeInsets.only(top: 40.0, bottom: 16.0),
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : _error != null
                      ? Text(_error!, style: AppTextStyles.body)
                      : Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: AssetImage('assets/Frame.png'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _userData?['username'] ?? 'Unknown User',
                        style: AppTextStyles.subheading.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userData?['email'] ?? 'user@example.com',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Settings List
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        return _buildListTile(
                          context,
                          icon: _items[index]['icon'] as IconData,
                          title: _items[index]['title'] as String,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                  _items[index]['screen'] as Widget),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Logout Button
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextButton(
                    onPressed: () => _handleLogout(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Logout',
                      style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600, color: Colors.redAccent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
