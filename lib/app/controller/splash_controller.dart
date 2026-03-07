import 'dart:async';
import 'package:flutter_app/app/backend/api/api.dart';
import 'package:flutter_app/app/controller/session_controller.dart';
import 'package:flutter_app/app/helper/shared_pref.dart';
import 'package:get/get.dart';

class SplashController extends GetxController implements GetxService {
  final SharedPreferencesManager sharedPreferencesManager;
  final ApiService apiService;

  SplashController({required this.sharedPreferencesManager, required this.apiService});

  Future<bool> initSharedData() {
    final sessionStore = Get.find<SessionController>();
    sessionStore.initStore(sharedPreferencesManager, apiService);
    return Future.value(true);
  }
}
