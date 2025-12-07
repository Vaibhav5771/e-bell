import 'package:flutter/material.dart';

class WifiState extends ChangeNotifier {
  bool _isWifiConnected = false;
  String _connectionStatus = "Checking Wi-Fi...";
  bool _isLoading = true;

  bool get isWifiConnected => _isWifiConnected;
  String get connectionStatus => _connectionStatus;
  bool get isLoading => _isLoading;

  void updateWifiStatus(bool isConnected, String status) {
    _isWifiConnected = isConnected;
    _connectionStatus = status;
    _isLoading = false;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}