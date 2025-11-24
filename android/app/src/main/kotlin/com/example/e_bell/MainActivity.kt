package com.example.e_bell

import android.content.Intent
import android.os.Build
import android.provider.AlarmClock
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.e_bell/methods"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "openAlarmSettings") {
                    try {
                        // Primary: Open Alarms tab in default Clock app (works on Android 4.4+)
                        val intent = Intent(AlarmClock.ACTION_SHOW_ALARMS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        // Fallback 1: Open "create new alarm" screen
                        try {
                            val fallback = Intent(AlarmClock.ACTION_SET_ALARM)
                            fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(fallback)
                            result.success(true)
                        } catch (e2: Exception) {
                            // Fallback 2: Open full Sound settings (always available)
                            val soundSettings = Intent(Settings.ACTION_SOUND_SETTINGS)
                            soundSettings.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(soundSettings)
                            result.success(true)
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}