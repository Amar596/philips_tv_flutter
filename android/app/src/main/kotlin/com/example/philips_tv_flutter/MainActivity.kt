package com.example.philips_tv_flutter

import io.flutter.embedding.android.FlutterActivity
import android.content.IntentFilter
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger

class MainActivity : FlutterActivity() {

    companion object {
        const val EVENT_CHANNEL = "com.example.watchdog_app/wauly_events"
        const val METHOD_CHANNEL = "com.example.watchdog_app/test"
        private const val TAG = "WatchdogMainActivity"
    }

    private lateinit var receiver: WaulyEventReceiver
    private var eventSink: EventChannel.EventSink? = null
    private var eventChannel: EventChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "=== onCreate called ===")
        
        // Register the BroadcastReceiver
        receiver = WaulyEventReceiver()
        val filter = IntentFilter(WaulyEventReceiver.ACTION)
        registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        Log.d(TAG, "✅ BroadcastReceiver registered for action: ${WaulyEventReceiver.ACTION}")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

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

                // Add a method channel for testing
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "sendTestBroadcast") {
                    sendTestBroadcast()
                    result.success("Test broadcast sent")
                } else {
                    result.notImplemented()
                }
            }
        
        Log.d(TAG, "✅ Channels registered on $EVENT_CHANNEL and $METHOD_CHANNEL")
    }


    private fun sendTestBroadcast() {
    val intent = Intent(WaulyEventReceiver.ACTION).apply {
        putExtra("crash_text", "TEST EVENT from receiver at ${System.currentTimeMillis()}")
        putExtra("message", "TEST MESSAGE")
    };
    sendBroadcast(intent)
    //Log.d(TAG, "Test broadcast sent")
    }
    
    //Log.d(TAG, "✅ configureFlutterEngine CALLED — registering channel: $EVENT_CHANNEL")
    

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
