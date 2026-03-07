import 'dart:async';
import 'package:flutter_app/app/controller/session_controller.dart';
import 'package:get/get.dart';
// import 'package:flutter_app/app/backend/api/handler.dart';
// import 'package:flutter_app/app/backend/models/language_model.dart';
// import 'package:flutter_app/app/backend/models/settings_model.dart';
// import 'package:flutter_app/app/backend/models/support_model.dart';
import 'package:flutter_app/app/backend/parse/splash_parse.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';

class SplashController extends GetxController implements GetxService {
  final SplashParser parser;

  // late LanguageModel _defaultLanguage;
  // LanguageModel get defaultLanguage => _defaultLanguage;
  // late SettingsModel _settingsModel;
  // SettingsModel get settinsModel => _settingsModel;

  // late SupportModel _supportModel;
  // SupportModel get supportModel => _supportModel;
  SplashController({required this.parser});

  Future<bool> initSharedData() {
    final sessionStore = Get.find<SessionController>();
    sessionStore.initStore(parser.sharedPreferencesManager, parser.apiService);
    return parser.initAppSettings();
  }

  // Future<bool> getConfigData() async {
  //   Response response = await parser.getAppSettings();
  //   bool isSuccess = false;
  //   if (response.statusCode == 200) {
  //     Map<String, dynamic> myMap = Map<String, dynamic>.from(response.body);
  //     if (myMap['data'] != null) {
  //       dynamic body = myMap["data"];
  //       if (body['settings'] != null && body['support'] != null) {
  //         // SettingsModel appSettingsInfo =
  //         //     SettingsModel.fromJson(body['settings']);

  //         // _settingsModel = appSettingsInfo;

  //         // SupportModel supportModelInfo =
  //         //     SupportModel.fromJson(body['support']);
  //         // _supportModel = supportModelInfo;
  //         // parser.saveBasicInfo(
  //         //     appSettingsInfo.currencyCode,
  //         //     appSettingsInfo.currencySide,
  //         //     appSettingsInfo.currencySymbol,
  //         //     appSettingsInfo.smsName,
  //         //     appSettingsInfo.userVerifyWith,
  //         //     appSettingsInfo.userLogin,
  //         //     appSettingsInfo.email,
  //         //     appSettingsInfo.name,
  //         //     // appSettingsInfo.deliveryType,
  //         //     0,
  //         //     appSettingsInfo.deliveryCharge,
  //         //     appSettingsInfo.tax,
  //         //     appSettingsInfo.logo,
  //         //     '${supportModelInfo.firstName!} ${supportModelInfo.lastName!}',
  //         //     supportModelInfo.id,
  //         //     appSettingsInfo.mobile.toString(),
  //         //     appSettingsInfo.allowDistance);
  //         isSuccess = true;
  //       } else {
  //         isSuccess = false;
  //       }
  //     }
  //   } else {
  //     ApiChecker.checkApi(response);
  //     isSuccess = false;
  //   }
  //   update();
  //   return isSuccess;
  // }

  // String getLanguageCode() {
  //   return parser.getLanguagesCode();
  // }
}
