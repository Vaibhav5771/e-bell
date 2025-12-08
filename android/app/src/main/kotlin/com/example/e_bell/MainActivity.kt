package com.example.e_bell

import android.app.AlarmManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val ALARM_CHANNEL = "com.example.e_bell/alarm"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setupAlarmChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val wifiHandler = WifiHandler(applicationContext)
        wifiHandler.setupWifiChannel(flutterEngine)
    }

    private fun setupAlarmChannel() {
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            val channel = MethodChannel(messenger, ALARM_CHANNEL)
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "canScheduleExactAlarms" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager
                            result.success(alarmManager.canScheduleExactAlarms())
                        } else {
                            result.success(true) // No restriction before Android 12
                        }
                    }
                    "requestExactAlarmPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            try {
                                // Try the specific exact alarm settings intent
                                val intent = Intent("android.settings.REQUEST_SCHEDULE_EXACT_ALARM")
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                result.success(null)
                            } catch (e: Exception) {
                                // Fallback to app settings
                                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                intent.data = android.net.Uri.fromParts("package", packageName, null)
                                startActivity(intent)
                                result.success(null)
                            }
                        } else {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        } ?: run {
            android.util.Log.e("MainActivity", "Failed to initialize Alarm MethodChannel: flutterEngine or binaryMessenger is null")
        }
    }
}