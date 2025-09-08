/// LMS Platform Configuration
/// Controls which LMS platform the app connects to
class LMSConfig {
  /// The LMS platform to use: 'learnpress' or 'lifterlms'
  static String platform = 'lifterlms'; // Using LifterLMS
  
  /// LearnPress Configuration
  static const String learnPressUrl = 'https://your-learnpress-site.com';
  static const String learnPressApiPath = '/wp-json/llms/v1';
  
  /// LifterLMS Configuration  
  static const String lifterLMSUrl = 'https://your-lifterlms-site.com';
  static const String lifterLMSConsumerKey = 'ck_your_consumer_key';
  static const String lifterLMSConsumerSecret = 'cs_your_consumer_secret';
  
  /// Get the current platform name for display
  static String get platformName {
    switch (platform) {
      case 'lifterlms':
        return 'LifterLMS';
      case 'learnpress':
      default:
        return 'LearnPress';
    }
  }
  
  /// Check if using LearnPress
  static bool get isLearnPress => platform == 'learnpress';
  
  /// Check if using LifterLMS
  static bool get isLifterLMS => platform == 'lifterlms';
  
  /// Switch to a different platform
  static void switchPlatform(String newPlatform) {
    if (newPlatform == 'learnpress' || newPlatform == 'lifterlms') {
      platform = newPlatform;
    } else {
      throw ArgumentError('Invalid platform: $newPlatform. Must be "learnpress" or "lifterlms"');
    }
  }
  
  /// Get configuration for the current platform
  static Map<String, dynamic> getConfig() {
    if (isLearnPress) {
      return {
        'platform': 'learnpress',
        'baseUrl': learnPressUrl,
        'apiPath': learnPressApiPath,
      };
    } else {
      return {
        'platform': 'lifterlms',
        'baseUrl': lifterLMSUrl,
        'consumerKey': lifterLMSConsumerKey,
        'consumerSecret': lifterLMSConsumerSecret,
      };
    }
  }
}