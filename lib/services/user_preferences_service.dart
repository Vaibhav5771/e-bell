// services/user_preferences_service.dart
import 'package:flutter/foundation.dart';

class UserPreferencesService extends ChangeNotifier {
  String? _userSsid;

  String? get userSsid => _userSsid;

  void setUserSsid(String ssid) {
    _userSsid = ssid;
    notifyListeners();
  }

  void clearUserSsid() {
    _userSsid = null;
    notifyListeners();
  }
}