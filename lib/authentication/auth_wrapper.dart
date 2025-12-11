// auth_wrapper.dart - SIMPLIFIED FOR AUTO-LOGIN
import 'package:e_bell/authentication/register_page.dart';
import 'package:e_bell/authentication/splash.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/home_page.dart';
import '../utils/wifi_state.dart';
import 'auth_state.dart';
import 'login_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, authState, child) {
        print('🔄 AUTH WRAPPER: isLoading=${authState.isLoading}, uid=${authState.uid}');

        // 1. Show loading while checking auth state
        if (authState.isLoading) {
          print('🔄 AUTH WRAPPER: Showing loading screen');
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Checking login status...'),
                ],
              ),
            ),
          );
        }

        // 2. User is logged in - go to home
        if (authState.uid != null) {
          print('✅ AUTH WRAPPER: User logged in, going to HomeScreen');

          // Check Wi-Fi connection before going to home
          final wifiState = Provider.of<WifiState>(context);

          if (wifiState.isLoading) {
            print('📶 AUTH WRAPPER: Checking Wi-Fi connection');
            return SplashScreen(
              onConnectionChecked: (bool isConnected, String status) {
                print('📶 Splash callback: $isConnected, $status');
                wifiState.updateWifiStatus(isConnected, status);
              },
              userSsid: authState.ssid,
            );
          }

          return const HomeScreen();
        }

        // 3. No user logged in - show login screen
        print('❌ AUTH WRAPPER: No user, showing LoginScreen');
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
      },
    );
  }
}