import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';

import '../services/user_preferences_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Getter for currentUser
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      throw Exception('Sign-in failed: $e');
    }
  }

  // Sign up with email, password, and username
  Future<User> signUpWithEmailAndPassword(
      String email,
      String password,
      String username,
      String ssid,
      String devicePassword,
      ) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'username': username,
        'ssid': ssid.isNotEmpty ? ssid : 'IoGen_Speaker',
        'devicePassword': devicePassword.isNotEmpty ? devicePassword : '12345678',
        'avatarUrl': 'assets/avatar_1.png',
        'createdAt': FieldValue.serverTimestamp(),
      });


      return userCredential.user!;
    } catch (e) {
      throw Exception('Sign-up failed: $e');
    }
  }


  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      throw Exception('Failed to fetch user data: $e');
    }
  }

  // Sign out
  Future<void> signOut(BuildContext context) async { // Add context parameter
    try {
      // Clear user preferences before signing out
      final userPrefs = Provider.of<UserPreferencesService>(context, listen: false);
      userPrefs.clearUserSsid();

      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign-out failed: $e');
    }
  }
}