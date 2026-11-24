import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/custom_button.dart';

class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  final _urlController = TextEditingController();
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(AppConstants.baseUrlKey) ?? ApiClient.defaultBaseUrl;
    _urlController.text = url;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String _cleanUrl(String input) {
    String trimmed = input.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (!trimmed.endsWith('/api')) {
      trimmed = '$trimmed/api';
    }
    return trimmed;
  }

  Future<void> _testConnection() async {
    final targetUrl = _cleanUrl(_urlController.text);
    _urlController.text = targetUrl;

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = false;
    });

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));

      final healthUrl = targetUrl.endsWith('/api')
          ? '${targetUrl.substring(0, targetUrl.length - 4)}/api/health'
          : '$targetUrl/health';

      final res = await dio.get(healthUrl);

      if (res.statusCode == 200 && res.data != null) {
        final version = res.data['version'] ?? '1.0.0';
        final storage = res.data['storage'] ?? 'AWS S3';
        setState(() {
          _testSuccess = true;
          _testResult = '✅ Connected! Backend active (v$version, $storage)';
        });
      } else {
        setState(() {
          _testSuccess = false;
          _testResult = '⚠️ Server responded with HTTP ${res.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = '❌ Cannot connect to backend: ${e.toString().split('\n').first}\nTip: If using Wi-Fi, try preset 192.168.1.2:8080';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  Future<void> _saveUrl(String newUrl) async {
    final cleaned = _cleanUrl(newUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.baseUrlKey, cleaned);
    ApiClient().updateBaseUrl(cleaned);
    if (mounted) {
      Helpers.showSnackBar(context, 'Base URL updated to: $cleaned', isSuccess: true);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.dns_outlined, color: AppColors.primary, size: 22),
          SizedBox(width: 8),
          Text('Server Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a preset below or enter your server URL. Real phones on Wi-Fi should use the Wi-Fi LAN IP.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'API Base URL',
                hintText: 'http://192.168.1.2:8080/api',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // Test Connection Button
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                icon: _isTesting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check, size: 18),
                label: Text(_isTesting ? 'Testing connection...' : 'Test Connection'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isTesting ? null : _testConnection,
              ),
            ),

            if (_testResult != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _testSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testSuccess ? Colors.green.shade300 : Colors.red.shade300,
                  ),
                ),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _testSuccess ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),
            const Text(
              'Quick Presets (Tap to select):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),

            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.wifi, size: 16, color: AppColors.primary),
                  label: const Text('Wi-Fi Phone (192.168.1.2:8080)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  backgroundColor: Colors.blue.shade50,
                  onPressed: () {
                    _urlController.text = 'http://192.168.1.2:8080/api';
                    _testConnection();
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.usb, size: 16, color: AppColors.accent),
                  label: const Text('USB reverse (127.0.0.1:8080)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    _urlController.text = 'http://127.0.0.1:8080/api';
                    _testConnection();
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.usb, size: 16, color: AppColors.accent),
                  label: const Text('USB reverse (127.0.0.1:5050)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    _urlController.text = 'http://127.0.0.1:5050/api';
                    _testConnection();
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.phone_android, size: 16),
                  label: const Text('Android Emulator (10.0.2.2:8080)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    _urlController.text = AppConstants.defaultEmulatorBaseUrl;
                    _testConnection();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        CustomButton(
          text: 'Save URL',
          width: 110,
          height: 38,
          onPressed: () => _saveUrl(_urlController.text),
        ),
      ],
    );
  }
}
