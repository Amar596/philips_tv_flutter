package com.example.philips_tv_flutter

import io.flutter.embedding.android.FlutterActivity
import android.content.IntentFilter
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.os.Build
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import dev.fluttercommunity.plus.device_info.DeviceInfoPlusPlugin
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File
import android.net.Uri
import androidx.core.content.FileProvider
import android.provider.Settings
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {

    companion object {
        const val EVENT_CHANNEL = "com.example.watchdog_app/wauly_events"
        const val METHOD_CHANNEL = "com.example.watchdog_app/test"
        const val APK_CHANNEL = "apk_install"
        private const val TAG = "WatchdogMainActivity"
        const val AUTO_INSTALL_CHANNEL = "auto_install"
    }

    private lateinit var receiver: WaulyEventReceiver
    private var eventSink: EventChannel.EventSink? = null
    private var eventChannel: EventChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "=== onCreate called ===")
        
        // Register the BroadcastReceiver
        if (!::receiver.isInitialized) {
            receiver = WaulyEventReceiver()
            val filter = IntentFilter(WaulyEventReceiver.ACTION)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(receiver, filter)
            }
            
            Log.d(TAG, "✅ BroadcastReceiver registered")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register all plugins
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Set up EventChannel
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                Log.d(TAG, "✅ Flutter onListen CALLED")
                eventSink = sink
                
                WaulyEventReceiver.onEventReceived = { message ->
                    Handler(Looper.getMainLooper()).post {
                        Log.d(TAG, "Pushing to Flutter: $message")
                        sink.success(message)
                    }
                }
            }

            override fun onCancel(arguments: Any?) {
                Log.d(TAG, "Flutter onCancel called")
                eventSink = null
                WaulyEventReceiver.onEventReceived = null
            }
        })

        // Method channel for testing
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "sendTestBroadcast") {
                    sendTestBroadcast()
                    result.success("Test broadcast sent")
                } else {
                    result.notImplemented()
                }
            }


        // APK MethodChannel for installation operations
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            installApk(path)
                            result.success(true)
                        } else {
                            result.error("ERROR", "Path is null", null)
                        }
                    }
                    "getPackageVersion" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            val version = getPackageVersion(packageName)
                            Log.d(TAG, "Returning version: $version for package: $packageName")
                            result.success(version)
                        } else {
                            result.error("ERROR", "Package name is null", null)
                        }
                    }
                    "getPackageVersionCode" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            val versionCode = getPackageVersionCode(packageName)
                            result.success(versionCode)
                        } else {
                            result.error("ERROR", "Package name is null", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ADD THIS: Auto-Install MethodChannel for accessibility features
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTO_INSTALL_CHANNEL)
            .setMethodCallHandler { call, result ->
        when (call.method) {
            "autoClickInstall" -> {
                AutoInstallService.autoClickInstall()
                result.success(true)
            }
            "isAccessibilityEnabled" -> {
                val enabled = isAccessibilityServiceEnabled()
                result.success(enabled)
            }
            "requestAccessibility" -> {
                openAccessibilitySettings()
                result.success(true)
            }
            "resetFlags" -> {
                AutoInstallService.resetFlags()
                result.success(true)
            }
            else -> result.notImplemented()
        }
        }
    }

    private fun forceEnableAccessibility() {
    try {
        val serviceName = "${packageName}/${AutoInstallService::class.java.name}"
        
        // Method 1: Using settings put (requires root)
        if (isRooted()) {
            Runtime.getRuntime().exec(arrayOf("su", "-c", "settings put secure enabled_accessibility_services $serviceName"))
            Runtime.getRuntime().exec(arrayOf("su", "-c", "settings put secure accessibility_enabled 1"))
            Log.d(TAG, "✅ Accessibility force enabled via root")
        }
        
        // Method 2: Using shell commands (requires root)
        if (isRooted()) {
            val process = Runtime.getRuntime().exec("su")
            val output = process.outputStream
            output.write("settings put secure enabled_accessibility_services $serviceName\n".toByteArray())
            output.write("settings put secure accessibility_enabled 1\n".toByteArray())
            output.write("exit\n".toByteArray())
            output.flush()
            process.waitFor()
            Log.d(TAG, "✅ Accessibility enabled via shell")
        }
    } catch (e: Exception) {
        Log.e(TAG, "Failed to force enable accessibility: ${e.message}")
    }
    }

    private fun isRooted(): Boolean {
    return try {
        val process = Runtime.getRuntime().exec("su")
        process.outputStream.write("exit\n".toByteArray())
        process.waitFor() == 0
    } catch (e: Exception) {
        false
    }
    }

    private fun installApk(path: String) {
    try {
        Log.d(TAG, "📲 Installing APK from: $path")
        
        // Check if we can install packages
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !canInstallPackages()) {
            Log.d(TAG, "Requesting install permission")
            requestInstallPermission()
            return
        }
        
        val file = File(path)
        if (!file.exists()) {
            Log.e(TAG, "❌ APK file does not exist at: $path")
            return
        }

        val uri: Uri = FileProvider.getUriForFile(
            this,
            "$packageName.provider",
            file
        )

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }

        // Check if installer exists
        if (intent.resolveActivity(packageManager) != null) {
            startActivity(intent)
            Log.d(TAG, "✅ APK install intent launched")
            
            // Give time for the installer to open and trigger accessibility
            Handler(Looper.getMainLooper()).postDelayed({
                Log.d(TAG, "Waiting for accessibility service to handle install...")
            }, 500)
        } else {
            Log.e(TAG, "❌ No app found to handle APK install")
        }

    } catch (e: Exception) {
        Log.e(TAG, "❌ APK install failed: ${e.message}")
    }
    }

    // SINGLE getPackageVersion method (ONLY ONE)
    private fun getPackageVersion(packageName: String): String? {
        return try {
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            Log.d(TAG, "✅ Package $packageName found, version: ${packageInfo.versionName}")
            packageInfo.versionName
        } catch (e: PackageManager.NameNotFoundException) {
            Log.d(TAG, "ℹ️ Package not found: $packageName (this is normal if app not installed)")
            null
        }
    }

    // getPackageVersionCode method (ADD THIS)
    private fun getPackageVersionCode(packageName: String): Int? {
        return try {
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.longVersionCode.toInt()
            } else {
                packageInfo.versionCode
            }
            Log.d(TAG, "✅ Package $packageName versionCode: $versionCode")
            versionCode
        } catch (e: PackageManager.NameNotFoundException) {
            Log.d(TAG, "ℹ️ Package not found: $packageName")
            null
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedService1 = "$packageName/.AutoInstallService"
        val expectedService2 = "$packageName/$packageName.AutoInstallService"

        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        Log.d("ACCESS", "Enabled services: $enabledServices")

        return enabledServices.contains(expectedService1) ||
            enabledServices.contains(expectedService2)
    }
    
    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        startActivity(intent)
        Log.d(TAG, "Opened accessibility settings")
    }

    private fun sendTestBroadcast() {
        val intent = Intent(WaulyEventReceiver.ACTION).apply {
            putExtra("crash_text", "TEST EVENT from receiver at ${System.currentTimeMillis()}")
            putExtra("message", "TEST MESSAGE")
        }
        sendBroadcast(intent)
        Log.d(TAG, "Test broadcast sent")
    }

    private fun canInstallPackages(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun requestInstallPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
            startActivity(intent)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(receiver)
            Log.d(TAG, "BroadcastReceiver unregistered")
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver: ${e.message}")
        }
        WaulyEventReceiver.onEventReceived = null
        eventChannel?.setStreamHandler(null)
    }

    override fun onStart() {
        super.onStart()
        Log.d(TAG, "onStart called - flutterEngine attached: ${flutterEngine != null}")
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume called - checking eventChannel: $eventChannel")
    }
}