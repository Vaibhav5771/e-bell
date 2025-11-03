// services/home_services.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart';

import '../pages/home_page.dart';


class HomeServices {
  static const String targetSsid = "IoGen_Speaker";

  // Permission handling
  static Future<void> requestPermissions() async {
    Location location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        throw Exception("Location service is disabled");
      }
    }

    var status = await Permission.location.request();
    if (status.isDenied) {
      throw Exception("Location permission denied");
    } else if (status.isPermanentlyDenied) {
      throw Exception("Location permission permanently denied");
    }
  }

  // Wi-Fi monitoring
  static Future<WifiStatus> checkWifiConnection() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        String? wifiSSID = await NetworkInfo().getWifiName();
        String? cleanedSSID = wifiSSID?.replaceAll('"', '').trim();

        debugPrint("Raw Wi-Fi SSID: $wifiSSID");
        debugPrint("Cleaned Wi-Fi SSID: $cleanedSSID");

        bool isTargetWifi = cleanedSSID != null &&
            cleanedSSID.toLowerCase() == targetSsid.toLowerCase();

        return WifiStatus(
          isConnected: true,
          isTargetWifi: isTargetWifi,
          ssid: cleanedSSID ?? 'Unknown',
          status: isTargetWifi
              ? "Connected to $targetSsid"
              : "Connected to Wi-Fi: ${cleanedSSID ?? 'Unknown'}",
        );
      } else {
        return WifiStatus(
          isConnected: false,
          isTargetWifi: false,
          ssid: '',
          status: "Not connected to Wi-Fi",
        );
      }
    } catch (e) {
      debugPrint("Error checking Wi-Fi: $e");
      return WifiStatus(
        isConnected: false,
        isTargetWifi: false,
        ssid: '',
        status: "Error checking Wi-Fi: $e",
      );
    }
  }

  // Prayer times status check
  static Future<Map<String, dynamic>> checkPrayerTimesStatus() async {
    http.Client? client;
    try {
      client = http.Client();
      final response = await client.get(
        Uri.parse('http://192.168.2.1/regtime'),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('regtime API timed out');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('regtime API HTTP ${response.statusCode}');
      }

      final jsonData = jsonDecode(response.body);

      final namazList = (jsonData['NAMAZ'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      final poojaList = (jsonData['POOJA'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      debugPrint('regtime → NAMAZ: $namazList, POOJA: $poojaList');

      return {
        'namazTimes': namazList,
        'poojaTimes': poojaList,
      };
    } catch (e) {
      debugPrint('Error checking regtime: $e');
      throw Exception('Failed to check regtime status: $e');
    } finally {
      client?.close();
    }
  }

  // Fetch region status and alarm songs
  static Future<Map<String, dynamic>> fetchRegionStatus() async {
    http.Client? client;
    try {
      client = http.Client();
      final response = await client.get(
        Uri.parse('http://192.168.2.1/'),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Root API timed out'),
      );

      if (response.statusCode != 200) {
        throw Exception('Root API HTTP ${response.statusCode}');
      }

      final jsonData = jsonDecode(response.body);

      final regionList = (jsonData['region'] as List<dynamic>? ?? []);
      int poojaFlag = 0;
      int namazFlag = 0;
      for (var item in regionList) {
        if (item is Map) {
          if (item.containsKey('POOJA')) poojaFlag = item['POOJA'] ?? 0;
          if (item.containsKey('NAMAZ')) namazFlag = item['NAMAZ'] ?? 0;
        }
      }

      final alarmDataList = jsonData['alarmData'] as List<dynamic>? ?? [];
      List<AlarmSong> alarmSongs = [];
      if (alarmDataList.isNotEmpty) {
        final files = alarmDataList[0]['Filenames'] as List<dynamic>? ?? [];
        alarmSongs = files
            .where((file) {
          if (file.length < 7) return false;
          final h = file[1];
          final m = file[2];
          return h is int && m is int && h >= 0 && h <= 23 && m >= 0 && m <= 59;
        })
            .map((file) => AlarmSong.fromJson(file))
            .toList();
      }

      debugPrint('Fetched alarm songs: ${alarmSongs.map((s) => "${s.fileName} @ ${s.hour}:${s.minute}, days: ${s.days}, start: ${s.startTimestamp}").toList()}');

      return {
        'namazEnabled': namazFlag == 1,
        'sunriseEnabled': poojaFlag == 1,
        'alarmSongs': alarmSongs,
      };
    } catch (e) {
      debugPrint("Error fetching region status and alarm songs: $e");
      throw Exception("Failed to fetch region status and alarm songs: $e");
    } finally {
      client?.close();
    }
  }

  // Delete alarm
  static Future<void> deleteAlarm(AlarmSong alarm) async {
    final client = http.Client();

    try {
      final requestData = "${alarm.fileName},${alarm.hour},${alarm.minute},${alarm.startTimestamp},${alarm.endTimestamp},${alarm.days}";

      debugPrint("Sending delete request: $requestData");

      final response = await client.post(
        Uri.parse('http://192.168.2.1/delete/'),
        headers: {'Content-Type': 'text/plain'},
        body: requestData,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Delete alarm API timed out'),
      );

      if (response.statusCode != 200) {
        throw Exception('Delete alarm API HTTP ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  // Time sync
  static Future<void> syncTime(DateTime selectedDateTime) async {
    final client = http.Client();
    try {
      // Format: YYYY,MM,DD,HH,MM,SS
      final formattedTime =
          "${selectedDateTime.year},"
          "${selectedDateTime.month},"
          "${selectedDateTime.day},"
          "${selectedDateTime.hour},"
          "${selectedDateTime.minute},"
          "${selectedDateTime.second}";

      final response = await client.post(
        Uri.parse('http://192.168.2.1/settime'),
        headers: {'Content-Type': 'text/plain'},
        body: formattedTime,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Time sync API timed out'),
      );

      if (response.statusCode != 200) {
        throw Exception('Time sync API HTTP ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }
}

class WifiStatus {
  final bool isConnected;
  final bool isTargetWifi;
  final String ssid;
  final String status;

  WifiStatus({
    required this.isConnected,
    required this.isTargetWifi,
    required this.ssid,
    required this.status,
  });
}