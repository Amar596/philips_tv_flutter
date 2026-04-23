import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:philips_tv_flutter/services/remote_key_service.dart';
import 'package:philips_tv_flutter/services/terminal_data_service.dart';
import 'package:philips_tv_flutter/services/wauly_app_service.dart';
import 'package:philips_tv_flutter/widgets/key_feedback_overlay.dart';
import 'package:philips_tv_flutter/widgets/terminal_overlay.dart';
import 'screens/watchdog_screen.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'home_page.dart';
import 'screens/settings_screen.dart';
import 'package:webview_flutter/webview_flutter.dart' show WebViewController;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final hasPending = await WaulyAppManager.checkAndResumePendingInstallation();

  if (hasPending) {
    // App will exit after installation, no need to continue
    return;
  }

  // Initialize terminal services
  TerminalDataService().startCapturing();
  RemoteKeyService.startListening();

  // Set callback for 777 detection
  RemoteKeyService.on777Detected = () {
    print('🎉 777 detected - showing terminal overlay');
    KeyFeedbackOverlay.showKeyPressed('777 ✓');
    showTerminalOverlay();
  };

  final documentsDirectory = await getApplicationDocumentsDirectory();
  final path = join(documentsDirectory.path, 'events.db');
  runApp(const WatchdogApp());
}

void showTerminalOverlay() {
  final navigatorState = navigatorKey.currentState;
  if (navigatorState != null) {
    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const TerminalOverlay(),
          ),
        ),
      ),
    );

    navigatorState.overlay?.insert(overlayEntry);
  } else {
    print('❌ Cannot show overlay: navigatorKey not initialized');
  }
}

class WatchdogApp extends StatelessWidget {
  const WatchdogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Wauly Watchdog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Colors.greenAccent,
          secondary: Colors.cyanAccent,
        ),
      ),
      home: HomePage(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

// Add a MethodChannel to receive clicks from native
class WebViewHandler {
  static const MethodChannel _channel = MethodChannel('webview_channel');
  static WebViewController? webViewController;

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'clickUpdateButton') {
        await clickUpdateButtonInWebView();
      }
    });
  }

  static Future<void> clickUpdateButtonInWebView() async {
    if (webViewController != null) {
      // JavaScript to find and click the "Update Now" button
      await webViewController?.runJavaScript('''
        (function() {
          // Try to find button by text
          const buttons = document.querySelectorAll('button, input[type="button"], a');
          for (let btn of buttons) {
            if (btn.innerText && btn.innerText.toLowerCase().includes('update now')) {
              btn.click();
              console.log('Clicked Update Now button');
              return;
            }
            if (btn.value && btn.value.toLowerCase().includes('update now')) {
              btn.click();
              console.log('Clicked Update Now button by value');
              return;
            }
          }
          
          // Try to find by class or id containing 'update'
          const updateBtn = document.querySelector('[class*="update"], [id*="update"]');
          if (updateBtn) {
            updateBtn.click();
            console.log('Clicked by class/id containing update');
            return;
          }
          
          console.log('Update Now button not found');
        })();
      ''');
    }
  }
}
