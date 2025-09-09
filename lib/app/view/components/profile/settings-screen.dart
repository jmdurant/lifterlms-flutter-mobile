import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/controller/theme_controller.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:get/get.dart';
import 'package:watch_it/watch_it.dart';
import 'package:indexed/indexed.dart';

typedef OnNavigateCallback = void Function(int page);

class SettingsScreen extends WatchingStatefulWidget {
  final PageController pageController;
  final OnNavigateCallback goBack;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
  SettingsScreen(
      {super.key, required this.pageController, required this.goBack});
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late ThemeController themeController;

  @override
  void initState() {
    super.initState();
    themeController = Get.find<ThemeController>();
  }

  void onLogin() {
    Future.delayed(Duration.zero, () {
      Get.toNamed(AppRouter.getLoginRoute());
    });
  }

  var screenWidth =
      (window.physicalSize.shortestSide / window.devicePixelRatio);
  var screenHeight =
      (window.physicalSize.longestSide / window.devicePixelRatio);
  int pageActive = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawerEnableOpenDragGesture: false,
        body: Stack(children: <Widget>[
          Indexed(
            index: 1,
            child: Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: (276 / 375) * screenWidth,
                height: (209 / 375) * screenWidth,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                      image: AssetImage(
                        'assets/images/banner-my-course.png',
                      ),
                      fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).viewPadding.top + 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      IconButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          widget.goBack(0);
                        },
                        icon: const Icon(Icons.arrow_back),
                        color: Theme.of(context).iconTheme.color,
                        iconSize: 24,
                      ),
                      Text(
                        tr( LocaleKeys.settings_title),
                        style: TextStyle(
                          fontFamily: 'medium',
                          fontWeight: FontWeight.w500,
                          fontSize: 24,
                          color: Theme.of(context).textTheme.headlineSmall?.color,
                        ),
                      ),
                      Container(width: 40),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Column(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Get.toNamed(AppRouter.general),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Feather.settings,size: 18,),
                                  SizedBox(width: 5,),
                                  Text(
                                      tr(LocaleKeys.settings_general),
                                      style: TextStyle(
                                        fontFamily: 'medium',
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                      ))
                                ],
                              ),
                              Icon(
                                Ionicons.chevron_forward_outline,
                                size: 18,
                              )
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8,),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Get.toNamed(AppRouter.password),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Feather.lock,size: 18,),
                                  SizedBox(width: 5,),
                                  Text(
                                      tr(LocaleKeys.settings_password),
                                      style: TextStyle(
                                        fontFamily: 'medium',
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                      ))
                                ],
                              ),
                              Icon(
                                Ionicons.chevron_forward_outline,
                                size: 18,
                              )
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8,),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Get.toNamed(AppRouter.language),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Ionicons.language,size: 18,),
                                  SizedBox(width: 5,),
                                  Text(
                                      tr(LocaleKeys.language),
                                      style: TextStyle(
                                        fontFamily: 'medium',
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                      ))
                                ],
                              ),
                              Icon(
                                Ionicons.chevron_forward_outline,
                                size: 18,
                              )
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8,),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Get.toNamed(AppRouter.getMyCertificates()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Ionicons.ribbon_outline,size: 18,),
                                  SizedBox(width: 5,),
                                  Text(
                                      'My Certificates',
                                      style: TextStyle(
                                        fontFamily: 'medium',
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                      ))
                                ],
                              ),
                              Icon(
                                Ionicons.chevron_forward_outline,
                                size: 18,
                              )
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8,),
                      Obx(() => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                themeController.isDarkMode 
                                  ? Ionicons.moon 
                                  : Ionicons.sunny_outline,
                                size: 18,
                              ),
                              SizedBox(width: 5,),
                              Text(
                                'Dark Mode',
                                style: TextStyle(
                                  fontFamily: 'medium',
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: themeController.isDarkMode,
                            onChanged: (value) {
                              themeController.toggleTheme();
                            },
                            activeColor: Colors.blue,
                          ),
                        ],
                      )),
                    ],
                  ),
                )
              ]),
        ]));
  }
}
