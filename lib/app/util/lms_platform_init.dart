import 'package:flutter_app/app/backend/services/lms_platform_service.dart';
import 'package:flutter_app/app/backend/binding/lms_dynamic_binding.dart';
import 'package:flutter_app/app/config/lms_config.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper class to initialize the LMS platform
class LMSPlatformInit {
  
  /// Initialize the LMS platform based on configuration
  static Future<void> initialize({
    String? defaultPlatform,
    String? learnPressUrl,
    String? lifterLMSUrl,
    String? lifterLMSKey,
    String? lifterLMSSecret,
  }) async {
    // Load saved platform preference
    final prefs = await SharedPreferences.getInstance();
    final savedPlatform = prefs.getString('lms_platform');
    
    // Determine which platform to use
    final platform = savedPlatform ?? defaultPlatform ?? 'learnpress';
    
    // Set the platform
    LMSConfig.switchPlatform(platform);
    
    // Update configuration if provided
    if (learnPressUrl != null) {
      await prefs.setString('learnpress_base_url', learnPressUrl);
    }
    if (lifterLMSUrl != null) {
      await prefs.setString('lifterlms_base_url', lifterLMSUrl);
    }
    if (lifterLMSKey != null) {
      await prefs.setString('lifterlms_consumer_key', lifterLMSKey);
    }
    if (lifterLMSSecret != null) {
      await prefs.setString('lifterlms_consumer_secret', lifterLMSSecret);
    }
    
    // Initialize the platform service
    final service = LMSPlatformService();
    await service.init();
    Get.put(service);
    
    // Load the appropriate controllers
    LMSDynamicBinding().dependencies();
    
    print('LMS Platform initialized: ${LMSConfig.platformName}');
  }
  
  /// Quick setup for LearnPress
  static Future<void> setupLearnPress({
    required String baseUrl,
  }) async {
    await initialize(
      defaultPlatform: 'learnpress',
      learnPressUrl: baseUrl,
    );
  }
  
  /// Quick setup for LifterLMS
  static Future<void> setupLifterLMS({
    required String baseUrl,
    required String consumerKey,
    required String consumerSecret,
  }) async {
    await initialize(
      defaultPlatform: 'lifterlms',
      lifterLMSUrl: baseUrl,
      lifterLMSKey: consumerKey,
      lifterLMSSecret: consumerSecret,
    );
  }
  
  /// Get current platform info
  static Map<String, dynamic> getPlatformInfo() {
    return {
      'platform': LMSConfig.platform,
      'platformName': LMSConfig.platformName,
      'isLearnPress': LMSConfig.isLearnPress,
      'isLifterLMS': LMSConfig.isLifterLMS,
      'config': LMSConfig.getConfig(),
    };
  }
  
  /// Check if platform is initialized
  static bool get isInitialized {
    return Get.isRegistered<LMSPlatformService>() && 
           Get.find<LMSPlatformService>().isInitialized;
  }
}