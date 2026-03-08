import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/api/api.dart';
import 'package:flutter_app/app/backend/models/user_info_model.dart';
import 'package:flutter_app/app/controller/session_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/profile_controller.dart';
import 'package:flutter_app/app/helper/function_helper.dart';
import 'package:flutter_app/app/helper/shared_pref.dart';
import 'package:flutter_app/app/util/constant.dart';
import 'package:flutter_app/app/view/tabs.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

import '../helper/dialog_helper.dart';
import '../helper/router.dart';

class SettingsController extends GetxController {
  final SessionController sessionStore;
  final SharedPreferencesManager sharedPreferencesManager;
  final ApiService apiService;
  String st = "{}";

  TextEditingController currentPasswordController = TextEditingController();
  TextEditingController newPasswordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  TextEditingController deletePasswordController = TextEditingController();

  TextEditingController nicknameController = TextEditingController();
  TextEditingController bioController = TextEditingController();
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();

  XFile? selectedImage;
  int currentPage = 0;

  SettingsController({
    required this.sessionStore,
    required this.sharedPreferencesManager,
    required this.apiService,
  });

  @override
  void onInit() async {
    handleGetUserData();
    super.onInit();
  }

  handleGetUserData() {
    var userData = getUserInfo();
    nicknameController.text = userData.nickname ?? "";
    bioController.text = userData.description ?? "";
    firstNameController.text = userData.last_name ?? "";
    lastNameController.text = userData.first_name ?? "";
    if (userData.avatar_url.isNotEmpty) {
      selectedImage = XFile(userData.avatar_url);
    }
    update();
  }

  void activePage(int value) {
    currentPage = value;
    update();
  }

  String _getToken() {
    return sharedPreferencesManager.getString('token') ?? "";
  }

  UserInfoModel getUserInfo() {
    String temp = sharedPreferencesManager.getString('user_info') ?? "";
    UserInfoModel json = UserInfoModel();
    if (temp != "") {
      json = UserInfoModel.fromJson(jsonDecode(temp) as Map<String, dynamic>);
    }
    return json;
  }

  Future<void> submitPassword() async {
    var context = Get.context as BuildContext;
    final value = Get.find<ProfileController>();
    if (currentPasswordController.text.trim() == "") {
      Alert(
              context: context,
              title: tr(LocaleKeys.error),
              desc: tr(LocaleKeys.settings_currentPasswordIsRequired))
          .show();
      return;
    }
    if (newPasswordController.text.trim() == "") {
      Alert(
              context: context,
          title: tr(LocaleKeys.error),
          desc: tr(LocaleKeys.settings_newPasswordIsRequired))
          .show();
      return;
    }

    if (newPasswordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      Alert(
              context: context,
              title: tr(LocaleKeys.error),
              desc: tr(LocaleKeys.settings_passwordNotMatch))
          .show();
      return;
    }

    if (newPasswordController.text.trim() ==
        currentPasswordController.text.trim()) {
      Alert(
              context: context,
              title: tr(LocaleKeys.error),
              desc: tr(LocaleKeys.settings_passwordAlreadyExists))
          .show();
      return;
    }
    var param = {
      "old_password": currentPasswordController.text,
      "new_password": newPasswordController.text,
    };
    DialogHelper.showLoading();
    Response response = await apiService.postPrivate(
        AppConstants.changePassword, param, _getToken());
    DialogHelper.hideLoading();

    await Future.delayed(Duration(seconds: 1), () {
      if (response.statusCode == 200) {
        if (response.body["code"] == "success") {
          Alert(
                  context: context,
                  title: "Success",
                  desc: tr(st,args: [response.body["message"]])
          )
              .show();
          Future.delayed(Duration(seconds: 3), () {
            value.logout();
            currentPasswordController.text = "";
            newPasswordController.text = "";
            confirmPasswordController.text = "";
            Get.toNamed(AppRouter.home);
            update();
          });

        } else {
          Alert(
                  context: context,
              title: tr(LocaleKeys.error),
                  desc: tr('{}',args: [response.body["message"]]).toString()
          )
              .show();
        }
      }else{
        Alert(
            context: context,
            title: tr(LocaleKeys.error),
            desc:
            tr("{}",args: [response.body["message"]]).toString()
        )
            .show();
      }
    });
  }

  Future<void> deleteAccount() async {
    var context = Get.context as BuildContext;
    final value = Get.find<ProfileController>();
    var userInfo = getUserInfo();
    if (deletePasswordController.text.trim() == "") {
      Alert(
              context: context,
          title: tr(LocaleKeys.error),
              desc: tr(LocaleKeys.settings_currentPasswordIsRequired))
          .show();
      return;
    }

    var param = {
      "id": userInfo.id,
      "password": deletePasswordController.text,
    };
    context.loaderOverlay.show();
    Response response = await apiService.postPrivate(
        AppConstants.deletePassword, param, _getToken());
    context.loaderOverlay.hide();
    await Future.delayed(Duration(seconds: 1), () {
      if (response.statusCode == 200) {
        if (response.body["code"] == "success") {
          Alert(
                  context: context,
                  title: "Success",
                  desc: Text("{}").tr(args: [response.body["message"]]).toString()
          )
              .show();
          Future.delayed(Duration(seconds: 2),(){
            value.logout();
            Get.offAll(TabScreen());
            deletePasswordController.text = "";
            update();
          });

        } else {
          Alert(
                  context: context,
                  title: "Error",
                  desc:
                  Text("{}").tr(args: [response.body["message"]]).toString()
          )
              .show();
        }
      }
      else{
        Alert(
            context: context,
            title: "Error",
            desc:
            Text("{}").tr(args: [response.body["message"]]).toString()
        )
            .show();
      }
    });
  }

  void selectFromGallery(String kind) async {
    try {
      var file = await ImagePicker().pickImage(
        maxWidth: 1080,
        maxHeight: 1080,
        source: kind == 'gallery' ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 25,
      );
      if (file != null) {
        final croppedFile = await ImageCropper().cropImage(
            sourcePath: file.path,
            maxWidth: 250,
            maxHeight: 250,
            aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
            compressQuality: 100,
            uiSettings: [
              AndroidUiSettings(
                  toolbarTitle: 'Cropper',
                  toolbarColor: Colors.deepOrange,
                  toolbarWidgetColor: Colors.white,
                  lockAspectRatio: false),
              IOSUiSettings(title: 'Cropper',
                  aspectRatioLockEnabled: true,
                  resetAspectRatioEnabled:true,
                  rotateButtonsHidden: true,
                  rectWidth: 400,
                  rectHeight: 400
              ),
            ]);
        if (croppedFile != null) selectedImage = XFile(croppedFile.path);
      }
      update();
    } catch (_) {
      // Silently handle error
    }
  }

  Future<void> _updateUserDataFromServer() async {
    String? token = sharedPreferencesManager.getString('token');
    String? userId = sharedPreferencesManager.getString('user_id');
    Response response = await apiService.getPrivate(
        AppConstants.getUser + "/" + userId!, token!, null);
    if (response.statusCode == 200) {
      UserInfoModel user = UserInfoModel.fromJson(response.body);
      sharedPreferencesManager.putString('user_info', jsonEncode(user.toJson()));
      sessionStore.setUserInfo(user);
    }
  }

  void saveGeneral() async {
    var context = Get.context as BuildContext;
    try {
      DialogHelper.showLoading();
      UserInfoModel user = getUserInfo();
      var map = Map<String, dynamic>();
      map['first_name'] = firstNameController.text;
      map['last_name'] = lastNameController.text;
      map['nickname'] = nicknameController.text;
      map['description'] = bioController.text;
      if (selectedImage != null && !Helper.checkHttpOrHttps(selectedImage!.path)) {
        map['lp_avatar_file'] = File(selectedImage!.path);
      }
      Response response = await apiService.postPrivateMultipart(
          AppConstants.updateUser + user.id.toString(), map, _getToken());
      await Future.delayed(Duration(seconds: 1), () {
        if (response.status.isOk) {
          DialogHelper.hideLoading();
          if (response.body["code"] != null) {
            Alert(
                context: context,
                title: response.body['message'],
                buttons: [
                  DialogButton(
                    child: Text(
                      tr(LocaleKeys.alert_cancel),
                      style: TextStyle(color: Colors.white, fontFamily: 'medium'),
                    ),
                    onPressed: () => {Navigator.pop(context)},
                  ),
                ],
            ).show();
          } else {

            _updateUserDataFromServer();
            refresh();
            update();
            Alert(
                context: context,
                title: tr(LocaleKeys.settings_save),
                buttons: [
                  DialogButton(
                    child: Text(
                      tr(LocaleKeys.alert_cancel),
                      style: TextStyle(color: Colors.white, fontFamily: 'medium'),
                    ),
                    onPressed: () => {Navigator.pop(context)},
                  ),
                ],
            ).show();
          }
        } else {
          DialogHelper.hideLoading();
          Alert(
              context: context,
              title: response.body['message'],
              buttons: [
              DialogButton(
                child: Text(
                  tr(LocaleKeys.alert_cancel),
                  style: TextStyle(color: Colors.white, fontFamily: 'medium'),
                ),
                onPressed: () => {Navigator.pop(context)},
              ),
            ],
          ).show();
        }

      });
    } catch (_) {
      // ignored
    } finally {
      DialogHelper.hideLoading();
    }
  }
}
