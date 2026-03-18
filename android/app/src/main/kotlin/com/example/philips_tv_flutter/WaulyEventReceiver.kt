package com.example.philips_tv_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap

class WaulyEventReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION = "com.signalr.TESTCRASH_CRASH_EVENT"
        private const val TAG = "WaulyEventReceiver"
        private const val DEDUPE_WINDOW_MS = 1000

        // Callback to push events to Flutter
        var onEventReceived: ((String) -> Unit)? = null

        // Simple deduplication cache
        private val recentMessages = ConcurrentHashMap<String, Long>()
    }

    override fun onReceive(context: Context, intent: Intent) {

        Log.d(TAG, "=== onReceive called ===")
        Log.d(TAG, "Action: ${intent.action}")
        
        // Log all extras
        val extras: Bundle? = intent.extras
        var message = ""
        
        if (extras != null && !extras.isEmpty) {
            Log.d(TAG, "Extras keys: ${extras.keySet()}")
            for (key in extras.keySet()) {
                val value = extras.get(key)
                Log.d(TAG, "Extra $key: $value")
                // Capture the message from crash_text
                if (key == "crash_text" && value is String) {
                    message = value
                }
            }
        }
        
        if (message.isEmpty()) {
            message = "Unknown event"
        }

        // DEDUPLICATION LOGIC
        val now = System.currentTimeMillis()
        val lastTime = recentMessages[message]
        
        if (lastTime != null && (now - lastTime) < DEDUPE_WINDOW_MS) {
            Log.d(TAG, "⏭️ Duplicate event ignored: $message")
            return // Skip duplicate
        }
        
        // Store this message
        recentMessages[message] = now
        
        // Clean up old entries periodically
        if (recentMessages.size > 100) {
            val cutoff = now - DEDUPE_WINDOW_MS
            recentMessages.entries.removeAll { it.value < cutoff }
        }

        Log.d(TAG, "✅ Event received: $message")

        if (intent.action == ACTION) {
            if (onEventReceived != null) {
                onEventReceived?.invoke(message)
                Log.d(TAG, "✅ Event forwarded to Flutter")
            } else {
                Log.w(TAG, "⚠️ onEventReceived is NULL — Flutter not listening yet")
            }
        }
    }
}