package com.example.philips_tv_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class WaulyEventReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION = "com.signalr.TESTCRASH_CRASH_EVENT"
        private const val TAG = "WaulyEventReceiver"

        // Callback to push events to Flutter
        var onEventReceived: ((String) -> Unit)? = null
    }

    override fun onReceive(context: Context, intent: Intent) {

        Log.d(TAG, "=== onReceive called ===")
        Log.d(TAG, "Action: ${intent.action}")
        Log.d(TAG, "Intent flags: ${intent.flags}")
        
        // Log all extras
        val extras: Bundle? = intent.extras
        if (extras != null && !extras.isEmpty) {
            Log.d(TAG, "Extras keys: ${extras.keySet()}")
            for (key in extras.keySet()) {
                Log.d(TAG, "Extra $key: ${extras.get(key)}")
            }
        } else {
            Log.d(TAG, "Intent extras: null")
        }
        
        // Log.d(TAG, "Calling package: ${intent.`package`}")
        // Log.d(TAG, "Calling component: ${intent.component}")

        if (intent.action == ACTION) {
            // Try different possible extra keys
            var message = intent.getStringExtra("crash_text")
            if (message.isNullOrEmpty()) {
                message = intent.getStringExtra("message")
            }
            if (message.isNullOrEmpty()) {
                message = intent.getStringExtra("event")
            }
            if (message.isNullOrEmpty()) {
                // If no string extra found, create a descriptive message
                message = if (extras != null && !extras.isEmpty()) {
                    "Event with ${extras.size()} extras"
                } else {
                    "Event received (no message)"
                }
            }
            
            val finalMessage = message ?: "Wauly Event"
            val timestamp = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date())
            val fullMessage = "$finalMessage"

            //Log.d(TAG, "✅ Event received at $timestamp: $message")

            if (onEventReceived != null) {
                onEventReceived?.invoke(fullMessage)
                Log.d(TAG, "✅ Event forwarded to Flutter")
            } else {
                Log.w(TAG, "⚠️ onEventReceived is NULL — Flutter not listening yet")
            }
        } else {
            Log.d(TAG, "Ignoring action: ${intent.action}")
        }
    }
}