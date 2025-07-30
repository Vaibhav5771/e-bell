import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';

class AuthState extends ChangeNotifier {
  String? uid;
  String? email;
  String? username;
  String? avatarUrl;
  bool isNewUser = false;
  bool isLoading = true; // Track initialization

  AuthState() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        try {
          final userData = await AuthService().getUserData(user.uid);
          if (userData != null) {
            setUser(
              user.uid,
              userData['email'],
              userData['username'],
              userData['avatarUrl'],
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

  void setUser(String uid, String email, String username, String avatarUrl,
      {bool isNewUser = false}) {
    this.uid = uid;
    this.email = email;
    this.username = username;
    this.avatarUrl = avatarUrl;
    this.isNewUser = isNewUser;
    notifyListeners();
  }

  void clearUser() {
    uid = null;
    email = null;
    username = null;
    avatarUrl = null;
    isNewUser = false;
    notifyListeners();
  }
}