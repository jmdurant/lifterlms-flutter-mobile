import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_app/app/backend/mobx-store/init_store.dart';
import 'package:flutter_app/app/backend/mobx-store/session_store.dart';
import 'package:flutter_app/app/controller/lifterlms/my_profile_controller.dart';
import 'package:flutter_app/app/controller/settings_controller.dart';
import 'package:flutter_app/app/backend/parse/settings_parse.dart';
import 'package:flutter_app/app/backend/api/api.dart';
import 'package:flutter_app/app/helper/shared_pref.dart';
import 'package:flutter_app/app/view/components/profile/my-order-screen.dart';
import 'package:flutter_app/app/view/components/profile/profile-screen.dart';
import 'package:get/get.dart';
import 'package:flutter_app/app/util/theme.dart';
import 'package:watch_it/watch_it.dart';

import 'components/profile/settings-screen.dart';

class MyProfileScreen extends WatchingStatefulWidget {
  MyProfileScreen({Key? key}) : super(key: key);

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final sessionStore = locator<SessionStore>();

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: Duration(milliseconds: 100),
      curve: Curves.easeInOut,
    );
    _currentPage = page;
  }

  void _goBack() {
    _pageController.animateToPage(
      0,
      duration: Duration(milliseconds: 100),
      curve: Curves.easeInOut,
    );
    _currentPage = 0;
  }

  Widget _buildDot(int index) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 5),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _currentPage == index ? Colors.blue : Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MyProfileController>(builder: (value) {
      // Initialize SettingsController when needed
      if (!Get.isRegistered<SettingsParser>()) {
        Get.lazyPut(() => SettingsParser(
          apiService: Get.find<ApiService>(),
          sharedPreferencesManager: Get.find<SharedPreferencesManager>(),
          sessionStore: sessionStore,
        ));
      }
      if (!Get.isRegistered<SettingsController>()) {
        Get.lazyPut(() => SettingsController(
          sessionStore: sessionStore, 
          parser: Get.find<SettingsParser>()
        ));
      }
      return Column(children: [
        Expanded(
            child: PageView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
          },
          children: [
            // Profile component for LifterLMS
            ProfileView(
              goToPage: _goToPage,
              controller: value,
            ),
            SettingsScreen(
                pageController: _pageController, goBack: (page) => _goBack()),
            MyOrderScreen(
                pageController: _pageController, goBack: (page) => _goBack()),
          ],
        )),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < 3; i++)
              GestureDetector(
                onTap: () => _goToPage(i),
                child: Container(),
              ),
          ],
        ),
      ]);
    });
  }
}

class ProfileView extends StatelessWidget {
  final void Function(int) goToPage;
  final MyProfileController controller;
  
  const ProfileView({
    Key? key,
    required this.goToPage,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var screenWidth = (window.physicalSize.shortestSide / window.devicePixelRatio);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background image
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: (276 / 375) * screenWidth,
              height: (209 / 375) * screenWidth,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/banner-my-course.png'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(height: math.max(20, MediaQuery.of(context).viewPadding.top)),
              
              // Profile info
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Profile avatar - same logic as home screen
                      controller.lmsService.currentUser?['avatar_url'] != null &&
                              controller.lmsService.currentUser?['avatar_url'] != ""
                          ? Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(50),
                                  image: DecorationImage(
                                    fit: BoxFit.cover,
                                    image: NetworkImage(
                                        controller.lmsService.currentUser!['avatar_url']),
                                  )))
                          : CircleAvatar(
                              radius: 50,
                              backgroundImage: Image.asset(
                                'assets/images/default-user-avatar.jpg',
                              ).image,
                            ),
                      SizedBox(height: 16),
                      
                      // User info from lmsService (same as home screen)
                      Text(
                        controller.lmsService.currentUser?['name'] ?? 
                            (controller.firstNameController.text.isNotEmpty
                                ? '${controller.firstNameController.text} ${controller.lastNameController.text}'
                                : 'User Profile'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        controller.lmsService.currentUser?['email'] ?? 
                            (controller.emailController.text.isNotEmpty 
                                ? controller.emailController.text
                                : 'No email'),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 32),
                      
                      // Menu items
                      ListTile(
                        leading: Icon(Icons.shopping_cart),
                        title: Text('My Orders'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => goToPage(2),
                      ),
                      Divider(),
                      ListTile(
                        leading: Icon(Icons.settings),
                        title: Text('Settings'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => goToPage(1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class Page3 extends StatelessWidget {
  const Page3({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: const Text(
        "page 3",
        style: TextStyle(fontFamily: 'bold', color: Colors.black),
      ),
    );
  }
}
