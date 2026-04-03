package com.example.philips_tv_flutter

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class AutoInstallService : AccessibilityService() {
    
    companion object {
        private const val TAG = "AutoInstallService"
        var instance: AutoInstallService? = null
        private var installClicked = false
        private var openClicked = false
        private var retryCount = 0
        
        fun autoClickInstall() {
            Log.d(TAG, "autoClickInstall called")
            instance?.performInstallClick()
        }
        
        fun resetFlags() {
            installClicked = false
            openClicked = false
            retryCount = 0
            Log.d(TAG, "Flags reset")
        }
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_REQUEST_TOUCH_EXPLORATION_MODE or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            notificationTimeout = 50
        }
        setServiceInfo(info)
        
        Log.d(TAG, "✅ Accessibility Service Connected and Configured")
        
        Handler(Looper.getMainLooper()).postDelayed({
            if (!installClicked) {
                findAndClickInstallButton()
            }
        }, 500)
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val packageName = event?.packageName?.toString() ?: return
        
        Log.d(TAG, "Event: pkg=$packageName, type=${event.eventType}, class=${event.className}")
        
        val isInstallerRelated = packageName.contains("packageinstaller") ||
                                 packageName == "com.android.packageinstaller" ||
                                 packageName == "com.google.android.packageinstaller"
        
        if (isInstallerRelated) {
            Log.d(TAG, "📦 Installer window detected: $packageName")
            Log.d(TAG, "Current state - installClicked: $installClicked, openClicked: $openClicked")
            
            when (event.eventType) {
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                    Handler(Looper.getMainLooper()).postDelayed({
                        if (!installClicked) {
                            findAndClickInstallButton()
                        } else if (installClicked && !openClicked) {
                            // Give time for installation to complete
                            Handler(Looper.getMainLooper()).postDelayed({
                                findAndClickOpenButton()
                            }, 1500)
                        }
                    }, 500)
                }
            }
        }
        
        // Also check for installation complete screen
        if (event?.className?.toString()?.contains("InstallSuccess") == true ||
            event?.className?.toString()?.contains("InstallFinished") == true ||
            event?.className?.toString()?.contains("AppInstalled") == true) {
            Log.d(TAG, "🎉 Installation complete screen detected!")
            Handler(Looper.getMainLooper()).postDelayed({
                if (installClicked && !openClicked) {
                    findAndClickOpenButton()
                }
            }, 1000)
        }
    }
    
    private fun findAndClickInstallButton() {
        val root = rootInActiveWindow
        if (root == null) {
            Log.d(TAG, "Root window is null for INSTALL button")
            return
        }
        
        Log.d(TAG, "🔍 Searching for INSTALL button...")
        debugPrintButtons(root)
        
        // Priority 1: Look for INSTALL button
        val installTexts = listOf("INSTALL", "安装", "INSTALAR", "インストール", "INSTALLER")
        var installButton = findButtonByText(root, installTexts)
        
        // Priority 2: Look for standard button IDs
        if (installButton == null) {
            val buttonIds = listOf(
                "android:id/button1",
                "com.android.packageinstaller:id/install_button",
                "com.android.packageinstaller:id/ok_button"
            )
            installButton = findButtonById(root, buttonIds)
        }
        
        // Priority 3: Look for any clickable button with positive text
        if (installButton == null) {
            installButton = findButtonByText(root, listOf("OK", "ACCEPT", "YES", "CONTINUE", "NEXT"))
        }
        
        if (installButton != null && installButton.isClickable) {
            Log.d(TAG, "✅ Found INSTALL button: text=${installButton.text}")
            val clicked = installButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            if (clicked) {
                installClicked = true
                Log.d(TAG, "✅ INSTALL button clicked successfully!")
                
                // Schedule to look for OPEN button
                Handler(Looper.getMainLooper()).postDelayed({
                    findAndClickOpenButton()
                }, 3000)
            }
        } else {
            Log.d(TAG, "❌ INSTALL button not found, retrying...")
            Handler(Looper.getMainLooper()).postDelayed({
                if (!installClicked) {
                    findAndClickOpenButton() // Maybe already on open screen
                }
            }, 1000)
        }
    }
    
    private fun findAndClickOpenButton() {
        val root = rootInActiveWindow
        if (root == null) {
            Log.d(TAG, "Root window is null for OPEN button")
            retryCount++
            if (retryCount < 5) {
                Handler(Looper.getMainLooper()).postDelayed({
                    findAndClickOpenButton()
                }, 1000)
            }
            return
        }
        
        Log.d(TAG, "🔍 Searching for OPEN button (Attempt ${retryCount + 1})...")
        debugPrintButtons(root)
        
        // Priority 1: Look for OPEN button (MOST IMPORTANT)
        val openTexts = listOf(
            "OPEN",      // English
            "打开",      // Chinese
            "ABRIR",     // Spanish/Portuguese
            "開く",      // Japanese
            "ÖFFNEN",    // German
            "OUVRIR",    // French
            "APRI",      // Italian
            "OTWÓRZ",    // Polish
            "OPENEN"     // Dutch
        )
        
        var openButton = findButtonByText(root, openTexts)
        
        // Priority 2: Look for LAUNCH button
        if (openButton == null) {
            val launchTexts = listOf("LAUNCH", "START", "RUN")
            openButton = findButtonByText(root, launchTexts)
        }
        
        // Priority 3: Look for DONE button (fallback)
        if (openButton == null) {
            val doneTexts = listOf("DONE", "完成", "FINISH", "CLOSE")
            openButton = findButtonByText(root, doneTexts)
        }
        
        // Priority 4: Look by ID
        if (openButton == null) {
            val buttonIds = listOf(
                "android:id/button2",
                "com.android.packageinstaller:id/open_button",
                "com.android.packageinstaller:id/launch_button",
                "android:id/done_button"
            )
            openButton = findButtonById(root, buttonIds)
        }
        
        // Priority 5: Look by content description
        if (openButton == null) {
            val contentDescs = listOf("Open", "Launch", "Start", "Done")
            openButton = findButtonByContentDescription(root, contentDescs)
        }
        
        if (openButton != null && openButton.isClickable) {
            Log.d(TAG, "✅ Found OPEN/LAUNCH button: text=${openButton.text}")
            val clicked = openButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            if (clicked) {
                openClicked = true
                Log.d(TAG, "✅ OPEN button clicked successfully! App should launch now.")
                retryCount = 0
            } else {
                Log.d(TAG, "❌ Failed to click OPEN button")
            }
        } else {
            Log.d(TAG, "❌ OPEN button not found")
            retryCount++
            if (retryCount < 5) {
                Log.d(TAG, "Retrying in 1 second...")
                Handler(Looper.getMainLooper()).postDelayed({
                    findAndClickOpenButton()
                }, 1000)
            } else {
                Log.d(TAG, "Max retries reached, giving up on OPEN button")
            }
        }
    }
    
    private fun debugPrintButtons(node: AccessibilityNodeInfo) {
        try {
            if (node.isClickable && node.text != null) {
                Log.d(TAG, "Clickable button found: text='${node.text}', id='${node.viewIdResourceName}'")
            }
            
            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    debugPrintButtons(child)
                    child.recycle()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error printing buttons: ${e.message}")
        }
    }
    
    private fun findButtonByText(node: AccessibilityNodeInfo, texts: List<String>): AccessibilityNodeInfo? {
        val nodeText = node.text?.toString()
        if (nodeText != null) {
            for (text in texts) {
                if (nodeText.equals(text, ignoreCase = true) && node.isClickable) {
                    Log.d(TAG, "Found button by text: '$nodeText' matching '$text'")
                    return node
                }
            }
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val found = findButtonByText(child, texts)
                if (found != null) return found
            }
        }
        return null
    }
    
    private fun findButtonById(node: AccessibilityNodeInfo, ids: List<String>): AccessibilityNodeInfo? {
        val nodeId = node.viewIdResourceName
        if (nodeId != null) {
            for (id in ids) {
                if (nodeId == id && node.isClickable) {
                    Log.d(TAG, "Found button by ID: '$nodeId'")
                    return node
                }
            }
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val found = findButtonById(child, ids)
                if (found != null) return found
            }
        }
        return null
    }
    
    private fun findButtonByContentDescription(node: AccessibilityNodeInfo, descriptions: List<String>): AccessibilityNodeInfo? {
        val contentDesc = node.contentDescription?.toString()
        if (contentDesc != null) {
            for (desc in descriptions) {
                if (contentDesc.equals(desc, ignoreCase = true) && node.isClickable) {
                    Log.d(TAG, "Found button by content description: '$contentDesc'")
                    return node
                }
            }
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val found = findButtonByContentDescription(child, descriptions)
                if (found != null) return found
            }
        }
        return null
    }
    
    private fun performInstallClick() {
        Log.d(TAG, "Manual install click triggered")
        installClicked = false
        openClicked = false
        retryCount = 0
        findAndClickInstallButton()
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service Interrupted")
        instance = null
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "Accessibility Service Destroyed")
    }
}