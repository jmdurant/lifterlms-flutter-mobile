/// LifterLMS Mobile App Plugin Configuration
/// 
/// This file contains configuration for the LifterLMS Mobile App WordPress plugin
/// which provides additional functionality for mobile apps including:
/// - In-App Purchases (IAP) for Apple App Store and Google Play Store
/// - Push Notifications via Firebase
/// - Social Login authentication
/// - Mobile-specific REST API endpoints

class LifterLMSMobileConfig {
  // ============================================================================
  // Mobile App Plugin Endpoints
  // ============================================================================
  
  /// Get app configuration including enabled features and settings
  static const String getAppConfig = 'wp-json/llms/v1/mobile-app/config';
  
  /// Check enrollment status with IAP information
  static const String checkEnrollment = 'wp-json/llms/v1/mobile-app/check-enrollment';
  
  /// Get user's mobile-specific data
  static const String getUserMobileData = 'wp-json/llms/v1/mobile-app/user-data';
  
  // ============================================================================
  // In-App Purchase Endpoints
  // ============================================================================
  
  /// Get IAP product information for a course
  static const String getProductIAP = 'wp-json/llms/v1/mobile-app/product-iap';
  
  /// Verify IAP receipt from Apple or Google
  static const String verifyReceipt = 'wp-json/llms/v1/mobile-app/verify-receipt';
  
  // ============================================================================
  // Push Notification Endpoints
  // ============================================================================
  
  /// Register device for push notifications
  static const String registerDevice = 'wp-json/llms/v1/mobile-app/register-device';
  
  /// Unregister device from push notifications
  static const String deleteDevice = 'wp-json/llms/v1/mobile-app/delete-device';
  
  // ============================================================================
  // Social Login Endpoints
  // ============================================================================
  
  /// Check if social login is enabled
  static const String enableSocialLogin = 'wp-json/llms/v1/mobile-app/enable-social';
  
  /// Verify Google login
  static const String verifyGoogleLogin = 'wp-json/llms/v1/mobile-app/verify-google';
  
  /// Verify Apple login
  static const String verifyAppleLogin = 'wp-json/llms/v1/mobile-app/verify-apple';
  
  /// Verify Facebook login
  static const String verifyFacebookLogin = 'wp-json/llms/v1/mobile-app/verify-facebook';
  
  // ============================================================================
  // IAP Configuration
  // ============================================================================
  
  /// Apple App Store configuration
  static const bool appleIAPEnabled = true;
  static const bool appleSandboxMode = false; // Set to true for testing
  
  /// Google Play Store configuration
  static const bool googleIAPEnabled = true;
  
  /// List of course IDs available for IAP
  /// These should match the course IDs configured in WordPress admin
  static const List<int> iapCourseIds = [];
  
  // ============================================================================
  // Push Notification Configuration
  // ============================================================================
  
  /// Firebase configuration
  static const bool pushNotificationsEnabled = false;
  static const String firebaseProjectId = ''; // Your Firebase project ID
  
  /// Notification events to subscribe to
  static const List<String> notificationEvents = [
    'enrollment',
    'course_completion',
    'lesson_completion',
    'quiz_completion',
    'certificate_earned',
    'achievement_earned',
  ];
  
  // ============================================================================
  // Social Login Configuration
  // ============================================================================
  
  /// Enable/disable social login providers
  static const bool socialLoginEnabled = false;
  static const bool facebookLoginEnabled = false;
  static const bool googleLoginEnabled = false;
  static const bool appleLoginEnabled = true; // Always available on iOS
  
  // ============================================================================
  // Helper Methods
  // ============================================================================
  
  /// Check if a course is available for IAP
  static bool isCourseAvailableForIAP(int courseId) {
    return iapCourseIds.contains(courseId);
  }
  
  /// Get IAP product ID for a course
  /// In LifterLMS Mobile App plugin, the product ID is the course ID as a string
  static String getIAPProductId(int courseId) {
    return courseId.toString();
  }
  
  /// Format receipt data for verification
  static Map<String, dynamic> formatReceiptData({
    required String receiptData,
    required int courseId,
    required bool isIOS,
  }) {
    return {
      'receipt_data': receiptData,
      'course_id': courseId,
      'platform': isIOS ? 'ios' : 'android',
    };
  }
  
  /// Format device registration data
  static Map<String, dynamic> formatDeviceData({
    required String deviceToken,
    required String platform,
  }) {
    return {
      'device_token': deviceToken,
      'platform': platform,
    };
  }
  
  /// Format social login verification data
  static Map<String, dynamic> formatSocialLoginData({
    required String idToken,
    required String provider,
    String? email,
    String? name,
  }) {
    return {
      'id_token': idToken,
      'provider': provider,
      if (email != null) 'email': email,
      if (name != null) 'name': name,
    };
  }
}

/// IAP Product Status
enum IAPProductStatus {
  available,
  purchased,
  pending,
  unavailable,
}

/// Push Notification Type
enum PushNotificationType {
  enrollment,
  courseCompletion,
  lessonCompletion,
  quizCompletion,
  certificateEarned,
  achievementEarned,
  general,
}

/// Social Login Provider
enum SocialLoginProvider {
  google,
  facebook,
  apple,
}