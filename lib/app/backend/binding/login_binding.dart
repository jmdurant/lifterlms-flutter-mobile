import 'package:flutter_app/app/controller/lifterlms/login_controller.dart';
import 'package:flutter_app/app/controller/social_login_controller.dart';
import 'package:get/get.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() async {
    // Register the LifterLMS LoginController directly
    Get.lazyPut(() => LoginController());
    
    // Also register SocialLoginController if not already registered
    if (!Get.isRegistered<SocialLoginController>()) {
      Get.lazyPut(() => SocialLoginController());
    }
  }
}