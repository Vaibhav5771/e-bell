import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';

class AuthState extends ChangeNotifier {
  String? uid;
  String? email;
  String? username;
  String? avatarUrl;
  String? ssid;
  String? devicePassword;
  bool isNewUser = false;
  bool isLoading = true; // Track initialization

  AuthState() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        try {
          final userData = await AuthService().getUserData(user.uid);

          if (userData != null) {
            // 🔹 Auto-fix missing fields in Firestore for older users
            bool updated = false;

            if (!userData.containsKey('ssid') || (userData['ssid'] as String).isEmpty) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({'ssid': 'IoGen_Speaker'});
              userData['ssid'] = 'IoGen_Speaker';
              updated = true;
              debugPrint('Added default SSID for user ${user.uid}');
            }

            if (!userData.containsKey('devicePassword') ||
                (userData['devicePassword'] as String).isEmpty) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({'devicePassword': '12345678'});
              userData['devicePassword'] = '12345678';
              updated = true;
              debugPrint('Added default Device Password for user ${user.uid}');
            }

            if (updated) {
              debugPrint('User data auto-updated for missing fields.');
            }

            // 🔹 Update local state
            setUser(
              user.uid,
              userData['email'],
              userData['username'],
              userData['avatarUrl'],
              ssid: userData['ssid'],
              devicePassword: userData['devicePassword'],
              isNewUser: false,
            );
          }
        } catch (e) {
          debugPrint('Error fetching user data: $e');
        }
      } else {
        clearUser();
      }
      isLoading = false; // Auth state resolved
      notifyListeners();
    });
  }

  // 🔹 Modified setUser to include ssid and devicePassword
  void setUser(
      String uid,
      String email,
      String username,
      String avatarUrl, {
        String? ssid,
        String? devicePassword,
        bool isNewUser = false,
      }) {
    this.uid = uid;
    this.email = email;
    this.username = username;
    this.avatarUrl = avatarUrl;
    this.ssid = ssid ?? 'IoGen_Speaker';
    this.devicePassword = devicePassword ?? '12345678';
    this.isNewUser = isNewUser;
    notifyListeners();
  }

  void clearUser() {
    uid = null;
    email = null;
    username = null;
    avatarUrl = null;
    ssid = null;
    devicePassword = null;
    isNewUser = false;
    notifyListeners();
  }
}
