// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:philips_tv_flutter/services/wauly_app_service.dart';

// class SettingsScreen extends StatefulWidget {
//   const SettingsScreen({Key? key}) : super(key: key);

//   @override
//   State<SettingsScreen> createState() => _SettingsScreenState();
// }

// class _SettingsScreenState extends State<SettingsScreen> {
//   final TextEditingController _versionUrlController = TextEditingController();
//   final TextEditingController _apkUrlController = TextEditingController();
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadCurrentUrls();
//   }

//   Future<void> _loadCurrentUrls() async {
//     setState(() => _isLoading = true);

//     final prefs = await SharedPreferences.getInstance();
//     final savedVersionUrl =
//         prefs.getString(WaulyAppManager.KEY_CUSTOM_VERSION_URL);
//     final savedApkUrl = prefs.getString(WaulyAppManager.KEY_CUSTOM_APK_URL);

//     setState(() {
//       _versionUrlController.text =
//           savedVersionUrl ?? WaulyAppManager.versionUrl;
//       _apkUrlController.text = savedApkUrl ?? WaulyAppManager.apkUrl;
//       _isLoading = false;
//     });
//   }

//   Future<void> _saveUrls() async {
//     final versionUrl = _versionUrlController.text.trim();
//     final apkUrl = _apkUrlController.text.trim();

//     if (versionUrl.isEmpty || apkUrl.isEmpty) {
//       _showSnackBar('Please enter both URLs', isError: true);
//       return;
//     }

//     if (!versionUrl.startsWith('http://') &&
//         !versionUrl.startsWith('https://')) {
//       _showSnackBar('Version URL must start with http:// or https://',
//           isError: true);
//       return;
//     }

//     if (!apkUrl.startsWith('http://') && !apkUrl.startsWith('https://')) {
//       _showSnackBar('APK URL must start with http:// or https://',
//           isError: true);
//       return;
//     }

//     setState(() => _isLoading = true);

//     try {
//       await WaulyAppManager.saveCustomUrls(versionUrl, apkUrl);
//       _showSnackBar('URLs saved successfully!', isError: false);

//       // Test connection
//       await _testConnection();
//     } catch (e) {
//       _showSnackBar('Error saving URLs: $e', isError: true);
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _testConnection() async {
//     try {
//       final versionInfo = await WaulyAppManager.fetchLatestVersion();
//       if (versionInfo != null) {
//         _showSnackBar(
//           'Connection successful!\nLatest version: ${versionInfo.version}',
//           isError: false,
//           duration: const Duration(seconds: 4),
//         );
//       } else {
//         _showSnackBar('Could not fetch version info', isError: true);
//       }
//     } catch (e) {
//       _showSnackBar('Connection test failed: $e', isError: true);
//     }
//   }

//   Future<void> _resetToDefaults() async {
//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Reset URLs'),
//         content: const Text('Are you sure you want to reset to default URLs?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             child: const Text('Reset'),
//           ),
//         ],
//       ),
//     );

//     if (confirm == true) {
//       setState(() => _isLoading = true);
//       await WaulyAppManager.resetToDefaultUrls();
//       await _loadCurrentUrls();
//       _showSnackBar('Reset to default URLs', isError: false);
//       setState(() => _isLoading = false);
//     }
//   }

//   void _showSnackBar(String message,
//       {required bool isError, Duration? duration}) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: isError ? Colors.red : Colors.green,
//         duration: duration ?? const Duration(seconds: 2),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Server Configuration'),
//         elevation: 0,
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Info Card
//                   Card(
//                     color: Colors.blue.shade900,
//                     child: Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               Icon(Icons.info_outline,
//                                   color: Colors.blue.shade300),
//                               const SizedBox(width: 8),
//                               const Text(
//                                 'Server Configuration',
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             'Configure the server URLs for version checking and APK downloads.',
//                             style: TextStyle(color: Colors.grey.shade400),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 24),

//                   // Version URL Field
//                   _buildUrlField(
//                     controller: _versionUrlController,
//                     label: 'Version XML URL',
//                     hint: 'http://192.168.0.169:8080/version.xml',
//                     icon: Icons.cloud_download,
//                     helperText: 'URL pointing to the version.xml file',
//                   ),

//                   const SizedBox(height: 16),

//                   // APK URL Field
//                   _buildUrlField(
//                     controller: _apkUrlController,
//                     label: 'APK Download URL',
//                     hint: 'http://192.168.0.169:8080/WaulySignage.apk',
//                     icon: Icons.android,
//                     helperText: 'Direct download URL for the APK file',
//                   ),

//                   const SizedBox(height: 32),

//                   // Action Buttons
//                   Row(
//                     children: [
//                       Expanded(
//                         child: ElevatedButton.icon(
//                           onPressed: _saveUrls,
//                           icon: const Icon(Icons.save),
//                           label: const Text('Save'),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.green,
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: ElevatedButton.icon(
//                           onPressed: _testConnection,
//                           icon: const Icon(Icons.wifi),
//                           label: const Text('Test'),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.blue,
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),

//                   const SizedBox(height: 12),

//                   // Reset Button
//                   SizedBox(
//                     width: double.infinity,
//                     child: OutlinedButton.icon(
//                       onPressed: _resetToDefaults,
//                       icon: const Icon(Icons.restore),
//                       label: const Text('Reset to Default URLs'),
//                       style: OutlinedButton.styleFrom(
//                         foregroundColor: Colors.red,
//                         padding: const EdgeInsets.symmetric(vertical: 12),
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 32),

//                   // Current Configuration Display
//                   _buildCurrentConfigCard(),
//                 ],
//               ),
//             ),
//     );
//   }

//   Widget _buildUrlField({
//     required TextEditingController controller,
//     required String label,
//     required String hint,
//     required IconData icon,
//     required String helperText,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontWeight: FontWeight.w600,
//             fontSize: 14,
//           ),
//         ),
//         const SizedBox(height: 8),
//         TextField(
//           controller: controller,
//           style: const TextStyle(fontSize: 14),
//           decoration: InputDecoration(
//             prefixIcon: Icon(icon),
//             hintText: hint,
//             helperText: helperText,
//             helperStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8),
//             ),
//             filled: true,
//             fillColor: Colors.grey.shade900,
//           ),
//           maxLines: null,
//           keyboardType: TextInputType.url,
//         ),
//       ],
//     );
//   }

//   Widget _buildCurrentConfigCard() {
//     return Card(
//       color: Colors.grey.shade900,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Current Configuration',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 12),
//             _buildConfigRow('Version URL:', WaulyAppManager.versionUrl),
//             const Divider(color: Colors.grey),
//             _buildConfigRow('APK URL:', WaulyAppManager.apkUrl),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildConfigRow(String label, String value) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: TextStyle(
//             fontWeight: FontWeight.w600,
//             color: Colors.grey.shade500,
//             fontSize: 12,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           value,
//           style: const TextStyle(
//             fontSize: 13,
//             fontFamily: 'monospace',
//           ),
//           maxLines: 2,
//           overflow: TextOverflow.ellipsis,
//         ),
//       ],
//     );
//   }

//   @override
//   void dispose() {
//     _versionUrlController.dispose();
//     _apkUrlController.dispose();
//     super.dispose();
//   }
// }


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
      _apkUrlController.text = apkUrl;
      _isLoading = false;
    });
  }

  Future<void> _saveUrls() async {
    final ip = _ipController.text.trim();

    if (ip.isEmpty) {
      _showSnackBar('Please enter server IP address', isError: true);
      return;
    }

    // Validate IP format (basic validation)
    final ipPattern = RegExp(r'^[\d\.]+:\d+$');
    if (!ipPattern.hasMatch(ip)) {
      _showSnackBar('Invalid format. Use: 192.168.0.169:8080', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final versionUrl = _buildVersionUrl(ip);
      final apkUrl = _buildApkUrl(ip);

      await WaulyAppManager.saveCustomUrls(versionUrl, apkUrl);
      _showSnackBar('Server IP saved successfully!', isError: false);

      // Test connection
      await _testConnection();
    } catch (e) {
      _showSnackBar('Error saving IP: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testConnection() async {
    try {
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
        title:
            const Text('Reset Server', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Reset to default server (192.168.0.169:8080)?',
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
      await WaulyAppManager.resetToDefaultUrls();
      await _loadCurrentUrls();
      _showSnackBar('Reset to default server', isError: false);
      setState(() => _isLoading = false);
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
    final currentFullUrl = _ipController.text.isNotEmpty
        ? _buildVersionUrl(_ipController.text)
        : WaulyAppManager.versionUrl;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        //title: const Text('Server Configuration'),
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
                            'Enter the server IP address and port. The paths are automatically configured.',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // IP Address Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Server IP Address',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _ipController,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          prefixIcon:
                              const Icon(Icons.dns, color: Colors.greenAccent),
                          hintText: '192.168.0.169:8080',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          helperText: 'Enter IP address and port only',
                          helperStyle: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade700),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.greenAccent),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade900,
                        ),
                        keyboardType: TextInputType.text,
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Preview of full URLs
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Preview URLs:',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Row(
                        //   children: [
                        //     const Icon(Icons.cloud_download,
                        //         size: 14, color: Colors.greenAccent),
                        //     const SizedBox(width: 8),
                        //     const Text(
                        //       'Version:',
                        //       style:
                        //           TextStyle(color: Colors.grey, fontSize: 12),
                        //     ),
                        //     const SizedBox(width: 8),
                        //     Expanded(
                        //       child: Text(
                        //         currentFullUrl,
                        //         style: const TextStyle(
                        //           color: Colors.white70,
                        //           fontSize: 11,
                        //           fontFamily: 'monospace',
                        //         ),
                        //         maxLines: 1,
                        //         overflow: TextOverflow.ellipsis,
                        //       ),
                        //     ),
                        //   ],
                        // ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.android,
                                size: 14, color: Colors.greenAccent),
                            const SizedBox(width: 8),
                            const Text(
                              'APK:',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _ipController.text.isNotEmpty
                                    ? _buildApkUrl(_ipController.text)
                                    : WaulyAppManager.apkUrl,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
            _buildConfigRow('Server IP:', ip.isNotEmpty ? ip : 'Default'),
            const Divider(color: Colors.grey),
            _buildConfigRow('Full Version URL:', WaulyAppManager.versionUrl),
            const Divider(color: Colors.grey),
            _buildConfigRow('Full APK URL:', WaulyAppManager.apkUrl),
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
    _apkUrlController.dispose();
    super.dispose();
  }
}
