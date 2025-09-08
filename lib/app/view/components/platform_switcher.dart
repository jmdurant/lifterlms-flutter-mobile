import 'package:flutter/material.dart';
import 'package:flutter_app/app/config/lms_config.dart';
import 'package:flutter_app/app/backend/binding/lms_dynamic_binding.dart';
import 'package:flutter_app/app/backend/services/lms_platform_service.dart';
import 'package:get/get.dart';

/// A widget that allows switching between LearnPress and LifterLMS platforms
class PlatformSwitcher extends StatelessWidget {
  const PlatformSwitcher({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'LMS Platform',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPlatformButton(
                'LearnPress',
                LMSConfig.isLearnPress,
                () => _switchPlatform('learnpress'),
              ),
              const SizedBox(width: 12),
              _buildPlatformButton(
                'LifterLMS',
                LMSConfig.isLifterLMS,
                () => _switchPlatform('lifterlms'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Current: ${LMSConfig.platformName}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlatformButton(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Theme.of(Get.context!).primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive 
                  ? Theme.of(Get.context!).primaryColor 
                  : Colors.grey[300]!,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[700],
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  void _switchPlatform(String platform) async {
    if (LMSConfig.platform == platform) return;
    
    // Show loading dialog
    Get.dialog(
      const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Switching platform...'),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
    
    try {
      // Switch platform in config
      LMSConfig.switchPlatform(platform);
      
      // Update the service if it exists
      if (Get.isRegistered<LMSPlatformService>()) {
        final service = Get.find<LMSPlatformService>();
        await service.switchPlatform(platform);
      }
      
      // Reload controllers
      LMSDynamicBinding.reloadControllers();
      
      // Close dialog
      Get.back();
      
      // Show success message
      Get.snackbar(
        'Platform Switched',
        'Now using ${LMSConfig.platformName}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      
      // Navigate to home to reload
      Get.offAllNamed('/tabs');
      
    } catch (e) {
      // Close dialog
      Get.back();
      
      // Show error
      Get.snackbar(
        'Error',
        'Failed to switch platform: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}

/// A simple dialog to show platform switcher
class PlatformSwitcherDialog extends StatelessWidget {
  const PlatformSwitcherDialog({Key? key}) : super(key: key);
  
  static void show() {
    Get.dialog(
      const PlatformSwitcherDialog(),
      barrierDismissible: true,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select LMS Platform',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const PlatformSwitcher(),
            ],
          ),
        ),
      ),
    );
  }
}