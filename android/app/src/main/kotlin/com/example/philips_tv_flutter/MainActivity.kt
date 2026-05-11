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
import android.content.BroadcastReceiver
import android.app.usage.StorageStatsManager
import android.os.storage.StorageManager
import java.util.UUID


class MainActivity : FlutterActivity() {

    companion object {
        const val EVENT_CHANNEL = "com.example.watchdog_app/wauly_events"
        const val METHOD_CHANNEL = "com.example.watchdog_app/test"
        const val APK_CHANNEL = "apk_install"
        private const val TAG = "WatchdogMainActivity"
        const val AUTO_INSTALL_CHANNEL = "auto_install"
        const val REMOTE_KEY_CHANNEL = "remote_key_channel"
    }

    private lateinit var receiver: WaulyEventReceiver
    private var eventSink: EventChannel.EventSink? = null
    private var eventChannel: EventChannel? = null
    private var remoteKeyChannel: MethodChannel? = null
    private val CHANNEL = "storage_info"

    // Track last key press to avoid duplicates
    private var lastKeyCode: Int = -1
    private var lastKeyTime: Long = 0
    private val KEY_DEBOUNCE_MS = 100L

    private var pendingResult: MethodChannel.Result? = null

    // Update the deviceControlReceiver to check if result is still pending
    // private val deviceControlReceiver = object : BroadcastReceiver() {
    //     override fun onReceive(context: Context?, intent: Intent?) {
    //         when (intent?.action) {
    //             "com.tpv.fq.reply.getModelName" -> {
    //                 pendingResult?.let { result ->
    //                     val modelName = intent.getStringExtra("modelName")
    //                     result.success(modelName)
    //                     pendingResult = null
    //                     try { unregisterReceiver(this) } catch(e: Exception) {}
    //                 }
    //             }
    //             "com.tpv.fq.reply.getPlatformName" -> {
    //                 pendingResult?.let { result ->
    //                     val platformName = intent.getStringExtra("platformName")
    //                     result.success(platformName)
    //                     pendingResult = null
    //                     try { unregisterReceiver(this) } catch(e: Exception) {}
    //                 }
    //             }
    //             "cms.intent.action.reply.getBACKLIGHT_STATUS" -> {
    //                 pendingResult?.let { result ->
    //                     val status = intent.getStringExtra("status")
    //                     result.success(status)
    //                     pendingResult = null
    //                     try { unregisterReceiver(this) } catch(e: Exception) {}
    //                 }
    //             }
    //             "cms.intent.action.reply.getBri" -> {
    //                 pendingResult?.let { result ->
    //                     val brightness = intent.getStringExtra("brightness")
    //                     result.success(brightness)
    //                     pendingResult = null
    //                     try { unregisterReceiver(this) } catch(e: Exception) {}
    //                 }
    //             }
    //         }
    //     }
    // }

    private val deviceControlReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "com.tpv.fq.reply.getModelName" -> {
                    pendingResult?.let { result ->
                        val modelName = intent.getStringExtra("modelName")
                        result.success(modelName)
                        pendingResult = null
                        try { 
                            unregisterReceiver(this) 
                        } catch(e: Exception) {
                            // Receiver already unregistered or not registered
                        }
                    }
                }
                "com.tpv.fq.reply.getPlatformName" -> {
                    pendingResult?.let { result ->
                        val platformName = intent.getStringExtra("platformName")
                        result.success(platformName)
                        pendingResult = null
                        try { 
                            unregisterReceiver(this) 
                        } catch(e: Exception) {}
                    }
                }
                "cms.intent.action.reply.getBACKLIGHT_STATUS" -> {
                    pendingResult?.let { result ->
                        val status = intent.getStringExtra("status")
                        result.success(status)
                        pendingResult = null
                        try { 
                            unregisterReceiver(this) 
                        } catch(e: Exception) {}
                    }
                }
                "cms.intent.action.reply.getBri" -> {
                    pendingResult?.let { result ->
                        val brightness = intent.getStringExtra("brightness")
                        result.success(brightness)
                        pendingResult = null
                        try { 
                            unregisterReceiver(this) 
                        } catch(e: Exception) {}
                    }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        autoEnableAccessibility() 
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

    // ✅ Method is at CLASS level, not inside onCreate
    private fun autoEnableAccessibility() {
        val serviceName = "$packageName/.AutoInstallService"
        Thread {
            try {
                val current = Settings.Secure.getString(
                    contentResolver,
                    Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
                ) ?: ""

                if (current.contains(serviceName)) {
                    Log.d(TAG, "✅ Accessibility already enabled, skipping")
                    return@Thread
                }

                Log.d(TAG, "🔧 Auto-enabling accessibility via root...")

                val process = Runtime.getRuntime().exec("su")
                val writer = process.outputStream.bufferedWriter()
                writer.write("settings put secure enabled_accessibility_services $serviceName\n")
                writer.flush()
                writer.write("settings put secure accessibility_enabled 1\n")
                writer.flush()
                writer.write("exit\n")
                writer.flush()
                process.waitFor()

                Log.d(TAG, "✅ Accessibility auto-enabled successfully")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Could not auto-enable accessibility: ${e.message}")
            }
        }.start()
    }

    private fun getSystemProperty(key: String, defaultValue: String = ""): String {
        return try {
            val clazz = Class.forName("android.os.SystemProperties")
            val method = clazz.getMethod("get", String::class.java, String::class.java)
            method.invoke(null, key, defaultValue) as String
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read system property: $key")
            defaultValue
        }
    }

    private fun getMacAddress(): String {
    return try {
        val interfaces = java.net.NetworkInterface.getNetworkInterfaces()

        for (intf in java.util.Collections.list(interfaces)) {
            if (!intf.name.equals("wlan0", ignoreCase = true)) continue

            val macBytes = intf.hardwareAddress ?: return ""

            val builder = StringBuilder()
            for (b in macBytes) {
                builder.append(String.format("%02X:", b))
            }

            if (builder.isNotEmpty()) {
                builder.deleteCharAt(builder.length - 1)
            }

            return builder.toString()
        }

        ""
    } catch (e: Exception) {
        Log.e(TAG, "Failed to get MAC address", e)
        ""
    }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shutdownDevice" -> {
                        val intent = Intent()
                        intent.action = "cms.intent.action.SHUTDOWN"
                        sendBroadcast(intent)
                        result.success("Shutdown broadcast sent")
                    }
                    "rebootDevice" -> {
                        val intent = Intent()
                        intent.action = "cms.intent.action.REBOOT"
                        sendBroadcast(intent)
                        result.success("Reboot broadcast sent")
                    }
                    "getStorage" -> {
                        try {
                            val storageManager = getSystemService(Context.STORAGE_SERVICE) as StorageManager
                            val totalBytes: Long
                            val freeBytes: Long
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val storageStatsManager =
                                    getSystemService(Context.STORAGE_STATS_SERVICE) as StorageStatsManager
                                totalBytes = storageStatsManager.getTotalBytes(StorageManager.UUID_DEFAULT)
                                freeBytes  = storageStatsManager.getFreeBytes(StorageManager.UUID_DEFAULT)
                            } else {
                                val path = android.os.Environment.getDataDirectory()
                                val stat = android.os.StatFs(path.path)
                                totalBytes = stat.blockSizeLong * stat.blockCountLong
                                freeBytes  = stat.blockSizeLong * stat.availableBlocksLong
                            }
                            result.success(mapOf("total" to totalBytes, "free" to freeBytes))
                        } catch (e: Exception) {
                            result.error("STORAGE_ERROR", e.message, null)
                        }
                    }
                     "setBacklight" -> {
                        val switchValue = call.argument<String>("switch")
                        val intent = Intent("cms.intent.action.BACKLIGHT_CNTRL")
                        intent.putExtra("switch", switchValue)
                        sendBroadcast(intent)
                        result.success("Backlight set to: $switchValue")
                    }
                    "getBacklightStatus" -> {
                        pendingResult = result
                        try {
                            registerReceiver(deviceControlReceiver, IntentFilter("cms.intent.action.reply.getBACKLIGHT_STATUS"))
                            val intent = Intent("cms.intent.action.getBACKLIGHT_STATUS")
                            sendBroadcast(intent)
                            
                            // Timeout fallback
                            Handler(Looper.getMainLooper()).postDelayed({
                                if (pendingResult != null) {
                                    val status = getSystemProperty("persist.sys.getBACKLIGHT_STATUS", "0")
                                    pendingResult?.success(status)
                                    pendingResult = null
                                    try { 
                                        unregisterReceiver(deviceControlReceiver) 
                                    } catch(e: Exception) {
                                        // Already unregistered
                                    }
                                }
                            }, 2000)
                        } catch(e: Exception) {
                            if (pendingResult != null) {
                                val status = getSystemProperty("persist.sys.getBACKLIGHT_STATUS", "0")
                                pendingResult?.success(status)
                                pendingResult = null
                            }
                        }
                    }
                    "getModelName" -> {
                        pendingResult = result
                        try {
                            registerReceiver(deviceControlReceiver, IntentFilter("com.tpv.fq.reply.getModelName"))
                            sendBroadcast(Intent("com.tpv.fq.getModelName"))
                            
                            Handler(Looper.getMainLooper()).postDelayed({
                                if (pendingResult != null) {
                                    val model = getSystemProperty("ro.product.name", "")
                                    pendingResult?.success(model)
                                    pendingResult = null
                                    try { 
                                        unregisterReceiver(deviceControlReceiver) 
                                    } catch(e: Exception) {
                                        // Receiver already unregistered
                                    }
                                }
                            }, 2000)
                        } catch(e: Exception) {
                            if (pendingResult != null) {
                                val model = getSystemProperty("ro.product.name", "")
                                pendingResult?.success(model)
                                pendingResult = null
                            }
                        }
                    }
                    "getPlatformName" -> {
                        pendingResult = result
                        try {
                            registerReceiver(deviceControlReceiver, IntentFilter("com.tpv.fq.reply.getPlatformName"))
                            sendBroadcast(Intent("com.tpv.fq.getPlatformName"))
                            
                            Handler(Looper.getMainLooper()).postDelayed({
                                if (pendingResult != null) {
                                    val platform = getSystemProperty("ro.board.platform", "")
                                    pendingResult?.success(platform)
                                    pendingResult = null
                                    try { 
                                        unregisterReceiver(deviceControlReceiver) 
                                    } catch(e: Exception) {
                                        // Receiver already unregistered
                                    }
                                }
                            }, 2000)
                        } catch(e: Exception) {
                            if (pendingResult != null) {
                                val platform = getSystemProperty("ro.board.platform", "")
                                pendingResult?.success(platform)
                                pendingResult = null
                            }
                        }
                    }
                    "getSerialNumber" -> {
                        val serial = getSystemProperty("ro.serialno", "")
                        result.success(serial)
                    }
                    "getModelNumber" -> {
                        val model = getSystemProperty("ro.product.model", "")
                        result.success(model)
                    }
                    "getMacAddress" -> {
                        val mac = getMacAddress()
                        result.success(mac)
                    }
                    "getAllDeviceDetails" -> {
                        val details = mapOf(
                            "serialNumber" to getSystemProperty("ro.serialno", ""),
                            "modelNumber" to getSystemProperty("ro.product.model", ""),
                            "modelName" to getSystemProperty("ro.product.name", ""),
                            "platformName" to getSystemProperty("ro.board.platform", ""),
                            "manufacturer" to android.os.Build.MANUFACTURER,
                            "device" to android.os.Build.DEVICE
                        )
                        result.success(details)
                    }
                    "getCurrentRotation" -> {
                        val rotation = getSystemProperty("persist.sys.screenorientation", "landscape")
                        result.success(rotation)
                    }
                    "setScreenRotation" -> {
                        val angle = call.argument<String>("angle")
                        val intent = Intent("cms.intent.action.ScreenRotation")
                        intent.putExtra("Angle", angle)
                        sendBroadcast(intent)
                        result.success("Screen rotation set to: $angle degrees")
                    }
                    "setScreenRotationWithBlackScreen" -> {
                        val angle = call.argument<String>("angle")
                        // Show black screen
                        val blackIntent = Intent("cms.intent.action.BLACK_SCREEN")
                        sendBroadcast(blackIntent)
                        
                        Handler(Looper.getMainLooper()).postDelayed({
                            val intent = Intent("cms.intent.action.ScreenRotation")
                            intent.putExtra("Angle", angle)
                            sendBroadcast(intent)
                        }, 100)
                        
                        Handler(Looper.getMainLooper()).postDelayed({
                            val hideIntent = Intent("cms.intent.action.HIDE_BLACK_SCREEN")
                            sendBroadcast(hideIntent)
                        }, 1100)
                        
                        result.success("Screen rotation with black screen set to: $angle degrees")
                    }
                    "getBrightness" -> {
                        pendingResult = result
                        try {
                            registerReceiver(deviceControlReceiver, IntentFilter("cms.intent.action.reply.getBri"))
                            val intent = Intent("cms.intent.action.getBri")
                            sendBroadcast(intent)
                            
                            Handler(Looper.getMainLooper()).postDelayed({
                                if (pendingResult != null) {
                                    val brightness = getSystemProperty("persist.sys.getBri", "0")
                                    pendingResult?.success(brightness)
                                    pendingResult = null
                                    try { 
                                        unregisterReceiver(deviceControlReceiver) 
                                    } catch(e: Exception) {
                                        // Receiver already unregistered
                                    }
                                }
                            }, 2000)
                        } catch(e: Exception) {
                            if (pendingResult != null) {
                                val brightness = getSystemProperty("persist.sys.getBri", "0")
                                pendingResult?.success(brightness)
                                pendingResult = null
                            }
                        }
                    }
                    "setBrightness" -> {
                        val brightness = call.argument<String>("brightness")
                        val intent = Intent("cms.intent.action.setBri")
                        intent.putExtra("brightness", brightness)
                        sendBroadcast(intent)
                        result.success("Brightness set to: $brightness")
                    }
                    "getDeviceInfo" -> {
                        val info = buildString {
                            appendLine("Serial: ${getSystemProperty("ro.serialno", "N/A")}")
                            appendLine("Model: ${getSystemProperty("ro.product.model", "N/A")}")
                            appendLine("Platform: ${getSystemProperty("ro.board.platform", "N/A")}")
                            appendLine("Android: ${android.os.Build.VERSION.RELEASE}")
                        }
                        result.success(info)
                    }
                    else -> result.notImplemented()
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
                    "autoClickUpdateButton" -> {
                        val buttonText = call.argument<String>("buttonText")
                        AutoInstallService.autoClickUpdateButton(buttonText ?: "Update Now")
                        result.success(true)
                    }
                    "isUpdateDialogShowing" -> {
                        val isShowing = AutoInstallService.checkForUpdateDialog()
                        result.success(isShowing)
                    }
                    "forceCheckForDialog" -> {
                       AutoInstallService.instance?.forceCheckForDialog()
                       result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

            // Add Remote Key Channel
            remoteKeyChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REMOTE_KEY_CHANNEL)
           
    }

    private fun safeUnregisterReceiver(receiver: BroadcastReceiver) {
    try {
        unregisterReceiver(receiver)
    } catch(e: IllegalArgumentException) {
        // Receiver was not registered
        Log.d(TAG, "Receiver was not registered: ${e.message}")
    } catch(e: Exception) {
        // Other error
        Log.e(TAG, "Error unregistering receiver: ${e.message}")
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


    private val webViewClickReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == "CLICK_UPDATE_BUTTON") {
            Log.d(TAG, "Received broadcast to click update button in WebView")
            clickUpdateButtonInWebView()
        }
    }
    }

    override fun onResume() {
    super.onResume()
    registerReceiver(webViewClickReceiver, IntentFilter("CLICK_UPDATE_BUTTON"))
    checkPendingInstallation()
    }

    override fun onPause() {
        super.onPause()
        try {
            unregisterReceiver(webViewClickReceiver)
        } catch (e: Exception) {
            // Ignore
        }
    }

    private fun clickUpdateButtonInWebView() {
    // Get the WebView from your Flutter view and execute JavaScript
    // You need to get a reference to your WebView widget
    // This depends on how you're displaying the HTML content
    
    // If using WebView widget, you can do:
    flutterEngine?.dartExecutor?.let {
        MethodChannel(it.binaryMessenger, "webview_channel")
            .invokeMethod("clickUpdateButton", null)
    }
    }   
    
    private fun checkPendingInstallation() {
    // Call Flutter to check and continue pending installation
    // You can use MethodChannel to communicate with Flutter
    if (AutoInstallService.instance != null) {
        // Accessibility is enabled, continue installation
        AutoInstallService.autoClickInstall()
    }
    }
}