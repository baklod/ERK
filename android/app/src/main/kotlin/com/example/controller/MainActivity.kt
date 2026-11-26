package com.example.controller

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        connectivityManager = getSystemService(ConnectivityManager::class.java)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "erk.eco.wave/wifi")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connect" -> {
                        val ssid = call.argument<String>("ssid")?.trim().orEmpty()
                        val password = call.argument<String>("password").orEmpty()
                        if (ssid.isEmpty()) {
                            result.error("bad_args", "Missing Wi-Fi name", null)
                        } else {
                            connectToBoat(ssid, password, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun connectToBoat(ssid: String, password: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("unsupported", "Android 10 or newer is required to join the boat Wi-Fi", null)
            return
        }

        releaseNetwork()
        if (password.isNotEmpty() && password.length < 8) {
            result.error("bad_args", "Wi-Fi password must be at least 8 characters", null)
            return
        }
        val specifier = WifiNetworkSpecifier.Builder().setSsid(ssid).apply {
            if (password.isNotEmpty()) setWpa2Passphrase(password)
        }.build()
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specifier)
            .build()

        val replied = AtomicBoolean(false)
        fun finish(block: () -> Unit) {
            if (replied.compareAndSet(false, true)) {
                mainHandler.post(block)
            }
        }

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                connectivityManager?.bindProcessToNetwork(network)
                finish { result.success(true) }
            }

            override fun onUnavailable() {
                finish { result.error("unavailable", "Could not join $ssid", null) }
            }
        }
        networkCallback = callback
        try {
            connectivityManager?.requestNetwork(request, callback)
        } catch (error: Exception) {
            finish { result.error("failed", error.message, null) }
        }
    }

    private fun releaseNetwork() {
        networkCallback?.let { callback ->
            runCatching { connectivityManager?.unregisterNetworkCallback(callback) }
        }
        networkCallback = null
    }

    override fun onDestroy() {
        connectivityManager?.bindProcessToNetwork(null)
        releaseNetwork()
        super.onDestroy()
    }
}
