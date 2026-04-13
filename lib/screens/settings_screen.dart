import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:philips_tv_flutter/services/wauly_app_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _versionUrlController = TextEditingController(); // NEW
  final TextEditingController _apkUrlController = TextEditingController();
  bool _isLoading = false;

  // Extract IP from URL
  String _extractIpFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.host}:${uri.port}';
    } catch (e) {
      return '';
    }
  }

  // Build version URL from IP
  String _buildVersionUrl(String ip) {
    return 'http://$ip/version.xml';
  }

  // Build APK URL from IP
  String _buildApkUrl(String ip) {
    return 'http://$ip/WaulySignage.apk';
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUrls();
  }

  Future<void> _loadCurrentUrls() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final savedVersionUrl =
        prefs.getString(WaulyAppManager.KEY_CUSTOM_VERSION_URL);
    final savedApkUrl = prefs.getString(WaulyAppManager.KEY_CUSTOM_APK_URL);

    final versionUrl = savedVersionUrl ?? WaulyAppManager.versionUrl;
    final apkUrl = savedApkUrl ?? WaulyAppManager.apkUrl;

    setState(() {
      _ipController.text = _extractIpFromUrl(versionUrl);
      _versionUrlController.text = versionUrl; // NEW: Display full version URL
      _apkUrlController.text = apkUrl;
      _isLoading = false;
    });
  }

  Future<void> _saveUrls() async {
    final customVersionUrl = _versionUrlController.text.trim();
    final customApkUrl = _apkUrlController.text.trim();

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Use the Azure Blob Storage URL as the default
      final defaultVersionUrl =
          'https://waulymvcapp.blob.core.windows.net/waulymvcdev/Builds/Android/Host/version.xml';
      final defaultApkUrl = ''; // Add your default APK URL here if needed

      // Case 1: Direct URLs provided (for cloud storage like Azure)
      if (customVersionUrl.isNotEmpty && customApkUrl.isNotEmpty) {
        await prefs.setString(
            WaulyAppManager.KEY_CUSTOM_VERSION_URL, customVersionUrl);
        await prefs.setString(WaulyAppManager.KEY_CUSTOM_APK_URL, customApkUrl);

        _showSnackBar('Custom URLs saved successfully!', isError: false);
      }
      // Case 2: Only one URL provided
      else if (customVersionUrl.isNotEmpty || customApkUrl.isNotEmpty) {
        if (customVersionUrl.isNotEmpty) {
          await prefs.setString(
              WaulyAppManager.KEY_CUSTOM_VERSION_URL, customVersionUrl);
        } else {
          // If only APK URL provided, use default version URL
          await prefs.setString(
              WaulyAppManager.KEY_CUSTOM_VERSION_URL, defaultVersionUrl);
        }
        if (customApkUrl.isNotEmpty) {
          await prefs.setString(
              WaulyAppManager.KEY_CUSTOM_APK_URL, customApkUrl);
        } else {
          // If only version URL provided, use default APK URL
          await prefs.setString(
              WaulyAppManager.KEY_CUSTOM_APK_URL, defaultApkUrl);
        }
        _showSnackBar('URLs saved successfully!', isError: false);
      } else {
        // Use default Azure URLs
        await prefs.setString(
            WaulyAppManager.KEY_CUSTOM_VERSION_URL, defaultVersionUrl);
        await prefs.setString(
            WaulyAppManager.KEY_CUSTOM_APK_URL, defaultApkUrl);

        _showSnackBar('Default Azure URLs loaded successfully!',
            isError: false);
      }

      // Reload current URLs to reflect changes
      await _loadCurrentUrls();

      // Test connection
      await _testConnection();
    } catch (e) {
      _showSnackBar('Error saving settings: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Future<void> _testConnection() async {
  //   try {
  //     final versionInfo = await WaulyAppManager.fetchLatestVersion();
  //     if (versionInfo != null) {
  //       _showSnackBar(
  //         'Connection successful!\nLatest version: ${versionInfo.version}',
  //         isError: false,
  //         duration: const Duration(seconds: 4),
  //       );
  //     } else {
  //       // Check if version URL points to APK instead of XML
  //       if (WaulyAppManager.versionUrl.toLowerCase().endsWith('.apk')) {
  //         _showSnackBar(
  //           '⚠️ Version URL points to APK file, not XML.\n'
  //           'Create a version.xml file or use separate URLs.\n'
  //           'APK URL is still valid for downloads.',
  //           isError: false,
  //           duration: const Duration(seconds: 5),
  //         );
  //       } else {
  //         _showSnackBar('Could not fetch version info', isError: true);
  //       }
  //     }
  //   } catch (e) {
  //     if (e.toString().contains('XmlParserException')) {
  //       _showSnackBar(
  //         '❌ Version URL must point to XML file (not APK)\n'
  //         'Current URL: ${WaulyAppManager.versionUrl}',
  //         isError: true,
  //         duration: const Duration(seconds: 5),
  //       );
  //     } else {
  //       _showSnackBar('Connection test failed: $e', isError: true);
  //     }
  //   }
  // }

  // In _testConnection() method
  Future<void> _testConnection() async {
    try {
      // ✅ CORRECT: Use fetchLatestVersion()
      final versionInfo = await WaulyAppManager.fetchLatestVersion();

      if (versionInfo != null) {
        _showSnackBar(
          'Connection successful!\nLatest version: ${versionInfo.version}',
          isError: false,
          duration: const Duration(seconds: 4),
        );
      } else {
        _showSnackBar('Could not fetch version info', isError: true);
      }
    } catch (e) {
      _showSnackBar('Connection test failed: $e', isError: true);
    }
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Reset to Default',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Reset to default Azure storage URLs?\n\n'
          'Version URL: https://waulymvcapp.blob.core.windows.net/waulymvcdev/Builds/Android/Host/version.xml',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final prefs = await SharedPreferences.getInstance();

        // Set to Azure default URLs
        final defaultVersionUrl =
            'https://waulymvcapp.blob.core.windows.net/waulymvcdev/Builds/Android/Host/version.xml';
        final defaultApkUrl = ''; // Add your default APK URL here if needed

        await prefs.setString(
            WaulyAppManager.KEY_CUSTOM_VERSION_URL, defaultVersionUrl);
        await prefs.setString(
            WaulyAppManager.KEY_CUSTOM_APK_URL, defaultApkUrl);

        // Update the static URLs in WaulyAppManager
        WaulyAppManager.versionUrl = defaultVersionUrl;
        WaulyAppManager.apkUrl = defaultApkUrl;

        await _loadCurrentUrls();
        _showSnackBar('Reset to default Azure URLs', isError: false);

        // Test connection with new URLs
        await _testConnection();
      } catch (e) {
        _showSnackBar('Error resetting to defaults: $e', isError: true);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message,
      {required bool isError, Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: duration ?? const Duration(seconds: 2),
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF0D1117),
    appBar: AppBar(
      backgroundColor: const Color(0xFF161B22),
      elevation: 0,
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                Card(
                  color: Colors.blue.shade900,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue.shade300),
                            const SizedBox(width: 8),
                            const Text(
                              'Server Configuration',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Option 1: Enter local server IP\n'
                          'Option 2: Enter direct URLs below (for cloud storage)',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                ),


                const SizedBox(height: 24),

                // Version URL Field (for version.xml)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'Option 2a: Version Info URL (XML)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Must point to a version.xml file containing version info',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _versionUrlController,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: 'https://example.com/version.xml',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade700),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue),
                          ),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // APK URL Field
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.android, size: 16, color: Colors.greenAccent),
                          const SizedBox(width: 8),
                          const Text(
                            'Option 2b: APK Download URL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Direct URL to the APK file for download',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _apkUrlController,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: 'https://example.com/app.apk',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade700),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.greenAccent),
                          ),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.3),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveUrls,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _testConnection,
                        icon: const Icon(Icons.wifi),
                        label: const Text('Test'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Reset Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _resetToDefaults,
                    icon: const Icon(Icons.restore),
                    label: const Text('Reset to Default Server'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Current Configuration Display
                _buildCurrentConfigCard(),
              ], 
            ), 
          ), 
    ); 
}

  Widget _buildCurrentConfigCard() {
    final ip = _extractIpFromUrl(WaulyAppManager.versionUrl);

    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Configuration',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _buildConfigRow('Server IP:', ip.isNotEmpty ? ip : 'Not set'),
            const Divider(color: Colors.grey),
            _buildConfigRow('Version URL (XML):', WaulyAppManager.versionUrl),
            const Divider(color: Colors.grey),
            _buildConfigRow('APK URL:', WaulyAppManager.apkUrl),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            color: Colors.white70,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    _versionUrlController.dispose();
    _apkUrlController.dispose();
    super.dispose();
  }
}