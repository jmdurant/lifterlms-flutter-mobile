import 'dart:math' as math;
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/controller/lifterlms/notification_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/home_controller.dart';
import 'package:flutter_app/app/backend/models/notification_model.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:indexed/indexed.dart';
import '../controller/notification_local_controller.dart';
import 'components/item-notification.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);


  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  NotificationController notificationController = Get.find<NotificationController>();
  var screenWidth =
      (window.physicalSize.shortestSide / window.devicePixelRatio);
  var screenHeight =
      (window.physicalSize.longestSide / window.devicePixelRatio);
  @override
  void initState(){
    NotificationLocalController.initialize(flutterLocalNotificationsPlugin);
    Future.delayed(Duration.zero, () async {
      // NotificationController initializes itself
      if(Get.arguments != null && Get.arguments is HomeController){
        final homeController = Get.arguments as HomeController;
        if (homeController.isNewNotification.value) {
          homeController.isNewNotification.value = false;
        }
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<NotificationController>(builder: (value) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        drawerEnableOpenDragGesture: false,
        body: Stack(children: <Widget>[
          Indexed(
            index: 1,
            child: Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                width: screenWidth,
                height: (209 / 375) * screenWidth,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.1),
                      Theme.of(context).primaryColor.withOpacity(0.05),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Indexed(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.fromLTRB(
                      0, MediaQuery.of(context).viewPadding.top + 10, 0, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      IconButton(
                        onPressed: () {
                          Get.back();
                        },
                        icon: const Icon(Icons.arrow_back),
                        color: Colors.grey[900],
                        iconSize: 24,
                      ),
                      Text(
                        tr( LocaleKeys.notification_title),
                        style: const TextStyle(
                          fontFamily: 'Poppins-Medium',
                          fontWeight: FontWeight.w500,
                          fontSize: 24,
                        ),
                      ),
                      Container(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await value.loadNotifications();
                    },
                    child: ListView.builder(
                        controller: value.scrollController,
                        itemCount: value.notifications.length +
                            (value.isLoading.value ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == value.notifications.length) {
                            return const Center(
                                child: SizedBox(
                              width: 20.0,
                              height: 20.0,
                              child: CircularProgressIndicator(),
                            ));
                          }
                          else if (index < value.notifications.length) {
                            // Convert Map to NotificationModel
                            final notificationData = value.notifications[index];
                            final model = NotificationModel(
                              notification_id: notificationData['id']?.toString(),
                              title: notificationData['title']?.toString() ?? '',
                              content: notificationData['body']?.toString() ?? '',
                              type: notificationData['category']?.toString() ?? 'general',
                              source: notificationData['data']?['course_id']?.toString(),
                              date_created: notificationData['timestamp']?.toString() ?? '',
                              status: notificationData['read'] == true ? 'read' : 'unread',
                            );
                            return ItemNotification(
                              item: model,
                            );
                          } else {
                            return Container(
                              margin: EdgeInsets.only(top: 50),
                              child: Text(
                                tr(LocaleKeys.notification_empty),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade500),
                              ),
                            );
                          }
                        }),
                  ),
                ),
              ]),
          ),
        ]),
      );
    });
  }
}
