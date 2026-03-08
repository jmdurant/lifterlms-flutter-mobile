import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class SiteConnection extends StatefulWidget {
  @override
  State<SiteConnection> createState() => _SiteConnectionState();

  SiteConnection({super.key});
}

class _SiteConnectionState extends State<SiteConnection> {
  final LMSService lmsService = LMSService.to;

  late TextEditingController siteUrlController;
  late TextEditingController consumerKeyController;
  late TextEditingController consumerSecretController;

  bool _isTesting = false;
  bool _isSaving = false;
  String? _testResultMessage;
  bool? _testResultSuccess;

  @override
  void initState() {
    super.initState();
    siteUrlController = TextEditingController(text: lmsService.baseUrl);
    consumerKeyController = TextEditingController(text: lmsService.consumerKey);
    consumerSecretController = TextEditingController(text: lmsService.consumerSecret);
  }

  @override
  void dispose() {
    siteUrlController.dispose();
    consumerKeyController.dispose();
    consumerSecretController.dispose();
    super.dispose();
  }

  String _cleanUrl(String url) {
    url = url.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResultMessage = null;
      _testResultSuccess = null;
    });

    final baseUrl = _cleanUrl(siteUrlController.text);
    final consumerKey = consumerKeyController.text.trim();
    final consumerSecret = consumerSecretController.text.trim();

    if (baseUrl.isEmpty || consumerKey.isEmpty || consumerSecret.isEmpty) {
      setState(() {
        _isTesting = false;
        _testResultMessage = 'All fields are required.';
        _testResultSuccess = false;
      });
      return;
    }

    try {
      final credentials = base64Encode(utf8.encode('$consumerKey:$consumerSecret'));
      final url = Uri.parse('$baseUrl/wp-json/llms/v1/courses?per_page=1');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Basic $credentials',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        setState(() {
          _testResultMessage = 'Connection successful!';
          _testResultSuccess = true;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _testResultMessage = 'Authentication failed. Check your API keys.';
          _testResultSuccess = false;
        });
      } else {
        setState(() {
          _testResultMessage = 'Connection failed (status ${response.statusCode}).';
          _testResultSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _testResultMessage = 'Could not connect to server. Check the URL.';
        _testResultSuccess = false;
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  Future<void> _saveConfiguration() async {
    final baseUrl = _cleanUrl(siteUrlController.text);
    final consumerKey = consumerKeyController.text.trim();
    final consumerSecret = consumerSecretController.text.trim();

    if (baseUrl.isEmpty || consumerKey.isEmpty || consumerSecret.isEmpty) {
      Get.snackbar(
        'Error',
        'All fields are required.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await lmsService.updateConfiguration(
        baseUrl: baseUrl,
        consumerKey: consumerKey,
        consumerSecret: consumerSecret,
      );

      Get.snackbar(
        'Success',
        'Site connection settings saved.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save settings.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawerEnableOpenDragGesture: false,
      body: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: screenWidth,
                  padding: EdgeInsets.only(
                      top: MediaQuery.of(context).viewPadding.top + 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back),
                        color: Theme.of(context).iconTheme.color,
                        iconSize: 26,
                      ),
                      Expanded(
                        child: Text(
                          'Site Connection',
                          style: TextStyle(
                            fontFamily: 'medium',
                            fontWeight: FontWeight.w500,
                            fontSize: 24,
                            color: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        // Site URL
                        Text(
                          'Site URL',
                          style: TextStyle(
                            fontFamily: 'medium',
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: siteUrlController,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              hintText: 'https://your-site.com',
                            ),
                            keyboardType: TextInputType.url,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Consumer Key
                        Text(
                          'Consumer Key',
                          style: TextStyle(
                            fontFamily: 'medium',
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: consumerKeyController,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              hintText: 'ck_...',
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Consumer Secret
                        Text(
                          'Consumer Secret',
                          style: TextStyle(
                            fontFamily: 'medium',
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: consumerSecretController,
                            obscureText: true,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              hintText: 'cs_...',
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Test result message
                        if (_testResultMessage != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: _testResultSuccess == true
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _testResultSuccess == true
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            child: Text(
                              _testResultMessage!,
                              style: TextStyle(
                                color: _testResultSuccess == true
                                    ? Colors.green[800]
                                    : Colors.red[800],
                                fontFamily: 'Poppins',
                                fontSize: 14,
                              ),
                            ),
                          ),
                        // Buttons
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlinedButton(
                              onPressed: _isTesting ? null : _testConnection,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                side: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              child: _isTesting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Test Connection',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _isSaving ? null : _saveConfiguration,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFBC815),
                                minimumSize: const Size(double.infinity, 46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Text(
                                      'Save',
                                      style: TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
