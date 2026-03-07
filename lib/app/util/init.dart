import 'package:flutter_app/app/backend/api/api.dart';
import 'package:flutter_app/app/controller/social_login_controller.dart';
import 'package:flutter_app/app/controller/language_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/notification_controller.dart';
import 'package:flutter_app/app/env.dart';
import 'package:flutter_app/app/helper/shared_pref.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

import '../controller/tabs_controller.dart';

class MainBinding extends Bindings {
  @override
  Future<void> dependencies() async {
    final sharedPref = await SharedPreferences.getInstance();
    Get.put(
      SharedPreferencesManager(sharedPreferences: sharedPref),
      permanent: true,
    );

    Get.lazyPut(() => ApiService(appBaseUrl: Environments.apiBaseURL));
    Get.lazyPut(() => NotificationController(), fenix: true);
    Get.lazyPut(() => LanguageController(sharedPreferencesManager: Get.find()),
        fenix: true);
    Get.lazyPut(() => TabControllerX(), fenix: true);
    Get.lazyPut(() => SocialLoginController(), fenix: true);
  }
}
