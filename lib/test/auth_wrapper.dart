import 'package:e_bell/test/register_page.dart';
import 'package:e_bell/test/splash.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/home_page.dart';
import 'auth_state.dart';
import 'login_page.dart';


class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState>(context);

    if (authState.isLoading) {
      return  SplashScreen(); // Show branded splash screen
    } else if (authState.uid != null) {
      return const HomeScreen(); // Auto-login to HomeScreen
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