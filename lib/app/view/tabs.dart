import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_app/app/controller/lifterlms/courses_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/home_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/my_courses_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/notification_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/payment_controller.dart';
import 'package:flutter_app/app/controller/tabs_controller.dart';
import 'package:flutter_app/app/util/theme.dart';
import 'package:flutter_app/app/view/courses.dart';
import 'package:flutter_app/app/view/home.dart';
import 'package:flutter_app/app/view/my_courses.dart';
import 'package:flutter_app/app/view/my_profile.dart';
import 'package:flutter_app/app/view/favorites_screen.dart';
import 'package:get/get.dart';
import 'package:watch_it/watch_it.dart';
import 'dart:io' show Platform;

import '../../l10n/locale_keys.g.dart';

class TabScreen extends WatchingStatefulWidget {
  TabScreen({super.key});

  @override
  _TabScreenState createState() => _TabScreenState();
}

class _TabScreenState extends State<TabScreen>
    with SingleTickerProviderStateMixin {
  Size size = WidgetsBinding.instance.window.physicalSize;
  var screenWidth = (window.physicalSize.shortestSide / window.devicePixelRatio);
  final List<Widget> _tabViews = [
    HomeScreen(),
    const CoursesScreen(),
    const MyCoursesScreen(),
    const FavoritesScreen(),
    MyProfileScreen()
  ];

  final TabControllerX controller = Get.put(TabControllerX());
  final CoursesController controllerCourse = Get.find<CoursesController>();
  final HomeController homeController = Get.find<HomeController>();
  final MyCoursesController myCoursesController = Get.find<MyCoursesController>();
  final PaymentController paymentController = Get.find<PaymentController>();
  final NotificationController notificationController = Get.find<NotificationController>();

  @override
  Widget build(BuildContext context) {
    bool isAndroid = Platform.isAndroid;
    return GetBuilder<TabControllerX>(
        builder: (value) {
      return Scaffold(
          body: TabBarView(
            physics: NeverScrollableScrollPhysics(),
            controller: controller.tabController,
            children: _tabViews,
          ),
          bottomNavigationBar: SafeArea(
            minimum: EdgeInsets.only(bottom: 10), // Smaller padding
            child:  Container(
              height: isAndroid?54:60, // Reduced iOS height
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                    topRight: Radius.circular(30), topLeft: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black38, spreadRadius: 0, blurRadius: 10),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child:  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          BottomNavigationBar(
                            backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
                            currentIndex: controller.tabId,
                            landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
                            onTap: (index) {
                              setState(() {
                                if (index == 0) {
                                  homeController.getOverview();
                                }
                                if (index == 2) {
                                  // Use cached data instead of refreshing every time
                                  myCoursesController.onTabVisible();
                                }
                                controller.updateTabId(index);
                              });
                            },
                            type: BottomNavigationBarType.fixed,
                            iconSize: 20,
                            selectedFontSize: 12,
                            unselectedFontSize: 12,
                            selectedLabelStyle: TextStyle(
                              color: Theme.of(context).primaryColor,
                            ),
                            unselectedLabelStyle: TextStyle(color: Theme.of(context).unselectedWidgetColor),
                            selectedItemColor: Theme.of(context).primaryColor,
                            unselectedItemColor: Theme.of(context).unselectedWidgetColor,
                            showUnselectedLabels: true,
                            elevation: 4,
                            items: [
                              BottomNavigationBarItem(
                                icon: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Image.asset(
                                    'assets/images/icon-tab/icon-tab-home.png',
                                    width: 20,
                                    height: 20,
                                    color: controller.tabId == 0
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).unselectedWidgetColor,
                                  ),
                                ),
                                label: tr(
                                    LocaleKeys.bottomNavigation_home)
                                    .toString(),
                              ),
                              BottomNavigationBarItem(
                                icon: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Image.asset(
                                    'assets/images/icon-tab/icon-tab-coures.png',
                                    // Replace with the actual image path and name
                                    width: 20,
                                    height: 20,
                                    color: controller.tabId == 1
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).unselectedWidgetColor,
                                  ),
                                ),
                                label: tr(
                                    LocaleKeys.bottomNavigation_courses)
                                    .toString(),
                              ),
                              BottomNavigationBarItem(
                                icon: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Image.asset(
                                    'assets/images/icon-tab/icon-my-course.png',
                                    // Replace with the actual image path and name
                                    width: 20,
                                    height: 20,
                                    color: controller.tabId == 2
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).unselectedWidgetColor,
                                  ),
                                ),
                                label: tr(
                                    LocaleKeys.bottomNavigation_myCourse)
                                    .toString(),
                              ),
                              BottomNavigationBarItem(
                                icon: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Image.asset(
                                    'assets/images/icon-tab/icon-wishlist.png',
                                    // Replace with the actual image path and name
                                    width: 20,
                                    height: 20,
                                    color: controller.tabId == 3
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).unselectedWidgetColor,
                                  ),
                                ),
                                label: tr(
                                    LocaleKeys.bottomNavigation_wishlist)
                                    .toString(),
                              ),
                              BottomNavigationBarItem(
                                icon: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Image.asset(
                                    'assets/images/icon-tab/icon-profile.png',
                                    // Replace with the actual image path and name
                                    width: 20,
                                    height: 20,
                                    color: controller.tabId == 4
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).unselectedWidgetColor,
                                  ),
                                ),
                                label: tr(LocaleKeys.bottomNavigation_profile),
                              ),
                            ],
                          ),
                          IndexedStack(
                            children: [
                              bottomHeightLight()
                            ],
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          )

      );
    });

  }

  Widget bottomHeightLight(){
      return Divider(
        color: Theme.of(context).primaryColor,
        height: 3,
        thickness: 3,
        indent: 20+(controller.tabId)*(screenWidth/5),
        endIndent: screenWidth - 60 - (controller.tabId)*(screenWidth/5),
      );
  }
}
