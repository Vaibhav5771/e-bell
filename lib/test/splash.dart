import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Image.asset('assets/appicon.png', height: 200),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 35.0), // Set padding between 30-40
              child: Image.asset('assets/iogicon.png', height: 60),
            ),
          ],
        ),
      ),
    );
  }
}