import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/api/api.dart';
import 'package:flutter_app/app/backend/models/notification_model.dart';
import 'package:flutter_app/app/helper/shared_pref.dart';
import 'package:flutter_app/app/util/constant.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:get/get.dart';

import '../helper/dialog_helper.dart';

class NotificationController extends GetxController implements GetxService {
  final SharedPreferencesManager sharedPreferencesManager;
  final ApiService apiService;
  bool apiCalled = false;

  bool haveData = false;

  List<NotificationModel> _notification = <NotificationModel>[];

  List<NotificationModel> get notificationList => _notification;
  final ScrollController scrollController = ScrollController();
  bool isLoading = false;
  bool isLoadingMore = true;
  int _page = 1;
  final int _pageSize = 10;

  NotificationController({
    required this.sharedPreferencesManager,
    required this.apiService,
  });

  String _getToken() {
    return sharedPreferencesManager.getString('token') ?? "";
  }

  @override
  Future<void> onInit() async {
    super.onInit();
    await refreshData();
    scrollController.addListener(_onScroll);
  }

  checkUpdateNotification(homeController) {
    if (homeController.isNewNotification) {
      homeController.updateShowNotification(false);
    }
  }

  Future<void> refreshData() async {
    _page = 1;
    isLoadingMore = true;
    _notification.clear();
    await getData();
  }

  @override
  void dispose() {
    scrollController.removeListener(scrollListener);
    super.dispose();
  }

  void scrollListener() {
    if (scrollController.offset >= scrollController.position.maxScrollExtent &&
        !scrollController.position.outOfRange) {
      if (!isLoadingMore) return;
      _loadMore();
    }
  }

  void _onScroll() {
    if (scrollController.position.pixels ==
        scrollController.position.maxScrollExtent) {
      if (!isLoadingMore) return;
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    _page = _page + 1;
    await getData();
  }

  // function to fetch courses from API
  Future<void> getData() async {
    if (!isLoading) {
      isLoading = true;

      try {
        String token = _getToken();
        final response = await apiService.getPrivate(
            AppConstants.getNotification, token, null);
        if (response.statusCode == 200) {
          List<NotificationModel> lstTemp = [];

          response.body["data"]["notifications"]?.forEach((item) {
            NotificationModel temp = NotificationModel.fromJson(item);
            lstTemp.add(temp);
          });
          if (lstTemp.length < _pageSize) {
            isLoadingMore = false;
          }
          _notification.addAll(lstTemp);
          if (await AppBadgePlus.isSupported()) {
            AppBadgePlus.updateBadge(0);
          }

          update();
          refresh();
        } else {
          if(_getToken() != ""){
            DialogHelper.showErrorDialog(title: 'Failed notifications', description: "Please update addons Announcement add-on for LearnPress version 4.0.5");
            throw Exception('Failed to load notifications');
          }
        }
      } catch (e) {
      } finally {
        isLoading = false; // hide loading indicator
        update();
        refresh();
      }
    }
  }

  Future<void> registerFCMToken(String fcmToken) async {
    try {
      String token = _getToken();
      Map<String, String> body = {
        'device_token': fcmToken,
        'device_type': Platform.isIOS ? 'ios' : 'android',
      };
      final response = await apiService.postPrivate(
          AppConstants.registerFCMToken, body, token);
      if (response.statusCode == 200) {
      } else {
        throw Exception('Failed to register FCMToken');
      }
    } catch (e) {
    } finally {}
  }

  Future<void> deleteFCMToken(fcmToken) async {
    try {
      String token = _getToken();
      Map<String, String> body = {'device_token': fcmToken};
      final response = await apiService.postPrivate(
          AppConstants.deleteFCMToken, body, token);
      if (response.statusCode == 200) {
      } else {
        throw Exception('Failed to delete FCMToken');
      }
    } catch (e) {
    } finally {}
  }
}
