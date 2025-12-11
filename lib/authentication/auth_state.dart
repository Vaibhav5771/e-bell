// auth_state.dart - FIXED FOR AUTO-LOGIN
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
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    print('🔐 AUTHSTATE: Starting initialization');

    try {
      // 1. FIRST: Check if user is already logged in (for auto-login)
      final currentUser = FirebaseAuth.instance.currentUser;
      print('🔐 AUTHSTATE: Firebase currentUser = ${currentUser?.uid}');

      if (currentUser != null) {
        print('🔐 AUTHSTATE: User found! Loading data...');
        await _loadUserData(currentUser);
      } else {
        print('🔐 AUTHSTATE: No user logged in');
        isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('🔐 AUTHSTATE ERROR: $e');
      isLoading = false;
      notifyListeners();
    }

    // 2. THEN: Listen for future auth changes (login/logout)
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      print('🔐 AUTHSTATE: Auth state changed: ${user?.uid}');

      if (user != null) {
        await _loadUserData(user);
      } else {
        clearUser();
      }

      if (isLoading) {
        isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserData(User user) async {
    try {
      print('🔐 AUTHSTATE: Loading data for user: ${user.uid}');

      final userData = await AuthService().getUserData(user.uid);

      if (userData != null) {
        print('🔐 AUTHSTATE: User data loaded successfully');
        setUser(
          user.uid,
          userData['email'] ?? user.email ?? '',
          userData['username'] ?? user.displayName ?? 'User',
          userData['avatarUrl'] ?? 'assets/avatar_1.png',
          ssid: userData['ssid'] ?? 'IoGen_Speaker',
          devicePassword: userData['devicePassword'] ?? '12345678',
          isNewUser: false,
        );
      } else {
        print('🔐 AUTHSTATE: No data in Firestore, using basic info');
        setUser(
          user.uid,
          user.email ?? '',
          user.displayName ?? 'User',
          'assets/avatar_1.png',
          ssid: 'IoGen_Speaker',
          devicePassword: '12345678',
          isNewUser: false,
        );
      }
    } catch (e) {
      print('🔐 AUTHSTATE ERROR loading data: $e');
      // Even on error, set basic info to allow login
      setUser(
        user.uid,
        user.email ?? '',
        user.displayName ?? 'User',
        'assets/avatar_1.png',
        ssid: 'IoGen_Speaker',
        devicePassword: '12345678',
        isNewUser: false,
      );
    }

    isLoading = false;
    notifyListeners();
  }

  void setUser(
      String uid,
      String email,
      String username,
      String avatarUrl, {
        String? ssid,
        String? devicePassword,
        bool isNewUser = false,
      }) {
    print('🔐 AUTHSTATE: Setting user - UID: $uid');

    this.uid = uid;
    this.email = email;
    this.username = username;
    this.avatarUrl = avatarUrl;
    this.ssid = ssid;
    this.devicePassword = devicePassword;
    this.isNewUser = isNewUser;

    notifyListeners();
  }

  void clearUser() {
    print('🔐 AUTHSTATE: Clearing user');
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