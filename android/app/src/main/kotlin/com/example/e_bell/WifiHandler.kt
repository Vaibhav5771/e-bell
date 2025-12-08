package com.example.e_bell

import android.content.Context
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSuggestion
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class WifiHandler(private val context: Context) {
    private val WIFI_CHANNEL = "wifi_connect"

    fun setupWifiChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIFI_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "connectToWifi") {
                val ssid = call.argument<String>("ssid")
                val password = call.argument<String>("password")
                if (ssid == null || password == null) {
                    result.error("INVALID_ARGS", "SSID or password missing", null)
                    return@setMethodCallHandler
                }
                val success = connectToWifi(ssid, password)
                if (success) {
                    result.success("Suggested Wi-Fi connection to $ssid")
                } else {
                    result.error("WIFI_ERROR", "Failed to suggest Wi-Fi connection", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun connectToWifi(ssid: String, password: String): Boolean {
        try {
            val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
            if (!wifiManager.isWifiEnabled) {
                wifiManager.isWifiEnabled = true
            }
            val suggestion = WifiNetworkSuggestion.Builder()
                .setSsid(ssid)
                .setWpa2Passphrase(password)
                .build()
            val suggestions = listOf(suggestion)
            val status = wifiManager.addNetworkSuggestions(suggestions)
            return status == WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }
}