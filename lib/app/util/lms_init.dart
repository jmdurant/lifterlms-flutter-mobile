import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:get/get.dart';

/// Initialize LMS services and dependencies
class LMSInit {
  static Future<void> initialize() async {
    // Initialize LMS Service
    await Get.putAsync(() => LMSService().init());
    
    // You can add more initialization here
    // For example, check if user is logged in, load cached data, etc.
  }
  
  /// Configure LMS for first time or when switching sites
  static Future<void> configureLMS({
    required String siteUrl,
    required String consumerKey,
    required String consumerSecret,
  }) async {
    final lmsService = LMSService.to;
    await lmsService.updateConfiguration(
      baseUrl: siteUrl,
      consumerKey: consumerKey,
      consumerSecret: consumerSecret,
    );
  }
}