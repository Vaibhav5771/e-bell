package com.example.e_bell

import android.app.AlarmManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.ReturnCode
import android.util.Log

class MainActivity : FlutterActivity() {
    private val ALARM_CHANNEL = "com.example.e_bell/alarm"
    private val FFMPEG_CHANNEL = "ffmpeg" // New channel for FFmpeg

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setupAlarmChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Set up Wi-Fi channel
        val wifiHandler = WifiHandler(applicationContext)
        wifiHandler.setupWifiChannel(flutterEngine)
        // Set up FFmpeg channel
        setupFFmpegChannel(flutterEngine)
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
                            result.success(true)
                        }
                    }
                    "requestExactAlarmPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            try {
                                val intent = Intent("android.settings.REQUEST_SCHEDULE_EXACT_ALARM")
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                result.success(null)
                            } catch (e: Exception) {
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
            Log.e("MainActivity", "Failed to initialize Alarm MethodChannel: flutterEngine or binaryMessenger is null")
        }
    }

    private fun setupFFmpegChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FFMPEG_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "run" -> {
                        val command: String? = call.argument("command")
                        if (command != null) {
                            Log.d("FFmpegBridge", "Executing: $command")
                            FFmpegKit.executeAsync(command) { session ->
                                Log.d("FFmpegBridge", "Command executed: ${session.state} ${session.returnCode}")
                                if (ReturnCode.isSuccess(session.returnCode)) {
                                    result.success("success")
                                } else {
                                    result.success("failed: ${session.returnCode}")
                                }
                            }
                        } else {
                            result.error("NO_COMMAND", "No FFmpeg command provided", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}