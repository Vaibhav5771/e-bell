// auth_wrapper.dart
// (Your existing code is actually fine, just ensure WifiState is updated)
import 'package:e_bell/authentication/register_page.dart';
import 'package:e_bell/authentication/splash.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/home_page.dart';
import '../utils/wifi_state.dart';
import 'auth_state.dart';
import 'login_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState>(context);
    final wifiState = Provider.of<WifiState>(context);

    if (authState.isLoading || wifiState.isLoading) {
      return SplashScreen(
        onConnectionChecked: (bool isConnected, String status) {
          // IMPORTANT: Update provider immediately so HomePage can see it
          wifiState.updateWifiStatus(isConnected, status);
        },
      );
    } else if (authState.uid != null) {
      return const HomeScreen();
    } else {
      return LoginScreen(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RegisterScreen(
                onTap: () => Navigator.pop(context),
              ),
            ),
          );
        },
      );
    }
  }
}