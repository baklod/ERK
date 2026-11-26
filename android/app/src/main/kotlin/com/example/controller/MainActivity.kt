package com.example.controller

import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private val relock = Runnable { lockLandscape() }
    private var focused = true
    private var correcting = false
    private var lastToggle = 0L
    private var forceAttempts = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lockLandscape()
    }

    override fun onResume() {
        super.onResume()
        lastToggle = 0
        forceAttempts = 0
        lockLandscape()
    }

    override fun onPause() {
        // Permission, Wi-Fi, and keyboard windows on this phone request portrait.
        // Commit landscape again before they take the screen.
        super.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE)
        super.onPause()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        focused = hasFocus
        if (hasFocus) {
            lastToggle = 0
            forceAttempts = 0
            lockLandscape()
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (newConfig.orientation != Configuration.ORIENTATION_LANDSCAPE) {
            lockLandscape()
        }
    }

    override fun setRequestedOrientation(requestedOrientation: Int) {
        super.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE)
    }

    private fun lockLandscape() {
        if (correcting) return
        val landscapeNow = resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        val alreadyLocked = requestedOrientation == ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        if (landscapeNow && alreadyLocked) {
            forceAttempts = 0
            mainHandler.removeCallbacks(relock)
            return
        }
        // A system dialog is in front and landscape is already requested. Wait
        // until this window is focused again, then force the rotation back.
        if (!focused && !landscapeNow && alreadyLocked) return
        if (forceAttempts >= 4) return
        val now = SystemClock.uptimeMillis()
        if (now - lastToggle < 250) {
            mainHandler.removeCallbacks(relock)
            mainHandler.postDelayed(relock, 260)
            return
        }
        lastToggle = now
        forceAttempts += 1
        correcting = true
        try {
            super.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE)
            super.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE)
        } finally {
            correcting = false
        }
    }

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "erk.eco.wave/orientation")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "lock" -> {
                        lastToggle = 0
                        forceAttempts = 0
                        lockLandscape()
                        result.success(null)
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
        mainHandler.removeCallbacks(relock)
        connectivityManager?.bindProcessToNetwork(null)
        releaseNetwork()
        super.onDestroy()
    }
}
