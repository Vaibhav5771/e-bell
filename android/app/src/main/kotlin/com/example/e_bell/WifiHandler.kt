package com.example.e_bell

import android.Manifest
import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSuggestion
import android.net.wifi.WifiNetworkSpecifier
import android.net.wifi.WifiEnterpriseConfig
import android.os.Build
import android.provider.Settings
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class WifiHandler(private val context: Context) {

    private val WIFI_CHANNEL = "com.example.e_bell/wifi"

    fun setupWifiChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIFI_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connectToWifi" -> {
                        val ssid = call.argument<String>("ssid")
                        val password = call.argument<String>("password")

                        if (ssid.isNullOrEmpty()) {
                            result.error("MISSING_SSID", "SSID is required", null)
                            return@setMethodCallHandler
                        }

                        val success = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            connectViaNetworkSuggestion(ssid, password.orEmpty())
                        } else {
                            false // Not supported below Android 10
                        }

                        if (success) {
                            result.success("Wi-Fi suggestion added. Check your Wi-Fi settings to connect.")
                        } else {
                            result.error("FAILED", "Could not add Wi-Fi suggestion", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun connectViaNetworkSuggestion(ssid: String, password: String): Boolean {
        return try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

            // Clear old suggestions (optional but clean)
            wifiManager.removeNetworkSuggestions(emptyList())

            val suggestion = WifiNetworkSuggestion.Builder()
                .setSsid(ssid)
                .apply {
                    if (password.isNotEmpty()) {
                        setWpa2Passphrase(password)
                    } else {
                        setIsAppInteractionRequired(true) // Open Wi-Fi (no password)
                    }
                }
                .setIsAppInteractionRequired(true) // Forces popup/notification
                .build()

            val status = wifiManager.addNetworkSuggestions(listOf(suggestion))

            when (status) {
                WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS -> {
                    // Optional: Open Wi-Fi settings so user can tap and connect
                    try {
                        context.startActivity(Intent(Settings.ACTION_WIFI_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        })
                    } catch (e: Exception) { /* Ignore if can't open */ }
                    true
                }
                WifiManager.STATUS_NETWORK_SUGGESTIONS_ERROR_ADD_DUPLICATE -> {
                    // Already exists — still good
                    true
                }
                else -> false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}