
import 'package:flutter_app/app/backend/api/api.dart';
import 'package:flutter_app/app/helper/shared_pref.dart';
import 'package:flutter_app/app/util/constant.dart';
import 'package:get/get.dart';

class SocialLoginController extends GetxController {
  final SharedPreferencesManager sharedPreferencesManager = Get.find();
  final ApiService apiService = Get.find();
  bool isEnableSocialLogin = false;

  @override
  void onInit() {
    //isSocialLoginEnable();
    super.onInit();
  }

  signInGoogle() async {
    //Google Sign In
    try {
    } catch (_) {
      // Silently handle error
    }
  }

  signInFacebook() async {
  }

  isSocialLoginEnable() async {
    Map<String, dynamic> body = Map<String, dynamic>();
    final response = await apiService.getPrivate(
        AppConstants.enableSocialLogin, '', body);
    isEnableSocialLogin = response.body;
    refresh();
    update();
    return false;
  }
}
