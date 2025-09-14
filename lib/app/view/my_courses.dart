import 'dart:math' as math;
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/controller/lifterlms/my_courses_controller.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/view/components/item-my-course.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:get/get.dart';
import 'package:indexed/indexed.dart';
import 'dart:io' show Platform;

class MyCoursesScreen extends StatefulWidget {
  const MyCoursesScreen({Key? key}) : super(key: key);

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastActiveTime;
  MyCoursesController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastActiveTime = DateTime.now();
    
    // Get controller and trigger data load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller = Get.find<MyCoursesController>();
      _controller?.onTabVisible();
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check if we should refresh when app comes back to foreground
      if (_lastActiveTime != null && 
          DateTime.now().difference(_lastActiveTime!) > const Duration(minutes: 10)) {
        final controller = Get.find<MyCoursesController>();
        controller.clearCache();
      }
      _lastActiveTime = DateTime.now();
    }
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

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MyCoursesController>(
      builder: (controller) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawerEnableOpenDragGesture: false,
        body: Stack(
          children: <Widget>[
            Indexed(
              index: 1,
              child: Positioned(
                right: 0,
                top: 0,
                left: 0,
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
            Column(
              children: <Widget>[
                SizedBox(height: math.max(20, MediaQuery.of(context).viewPadding.top)),
                !controller.lmsService.isLoggedIn
                    ? Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                tr(LocaleKeys.needLogin),
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                              SizedBox(
                                height: 20,
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 30),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                onPressed: onLogin,
                                child: Text(
                                  tr(LocaleKeys.login),
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          // Tab selector for course status
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildTabButton(controller, 0, 'All'),
                                _buildTabButton(controller, 1, 'In Progress'),
                                _buildTabButton(controller, 2, 'Completed'),
                                _buildTabButton(controller, 3, 'Not Started'),
                              ],
                            ),
                          ),
                        ],
                      ),
                (controller.lmsService.isLoggedIn)
                    ? Obx(() {
                        if (controller.isLoading.value && controller.totalCoursesCount == 0) {
                          return const Expanded(
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        
                        if (controller.hasError.value) {
                          return Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(controller.errorMessage.value),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => controller.refreshData(),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        
                        final courses = controller.getCoursesForTab();
                        
                        if (courses.isEmpty) {
                          return Expanded(
                            child: RefreshIndicator(
                              onRefresh: () async {
                                await controller.refreshData();
                              },
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.6,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            controller.selectedTab.value == 0 
                                                ? tr(LocaleKeys.dataNotFound)
                                                : 'No courses in this category',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Theme.of(context).textTheme.bodySmall?.color,
                                            ),
                                          ),
                                          if (controller.selectedTab.value == 0)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 16),
                                              child: ElevatedButton(
                                                onPressed: () => Get.toNamed(AppRouter.getCourses()),
                                                child: const Text('Browse Courses'),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        
                        return Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async {
                              await controller.refreshData();
                            },
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              controller: controller.scrollController,
                              itemCount: courses.length + 
                                  (controller.isLoadingMore.value ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == courses.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: SizedBox(
                                        width: 20.0,
                                        height: 20.0,
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  );
                                }
                                
                                return ItemMyCourse(
                                  item: courses[index],
                                  progress: controller.getProgressForCourse(courses[index].id),
                                  enrollmentDate: controller.getEnrollmentDate(courses[index].id),
                                  onContinue: () => controller.continueLearning(courses[index].id),
                                  onDetail: () => controller.goToCourseDetail(courses[index].id),
                                );
                              },
                            ),
                          ),
                        );
                      })
                    : Container(),
              ],
            ),
          ],
        ),
      );
    });
  }
  
  Widget _buildTabButton(MyCoursesController controller, int index, String label) {
    return Obx(() => GestureDetector(
      onTap: () => controller.setSelectedTab(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: controller.selectedTab.value == index 
              ? Theme.of(context).primaryColor 
              : Theme.of(context).dividerColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: controller.selectedTab.value == index 
                ? Theme.of(context).colorScheme.onPrimary 
                : Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: controller.selectedTab.value == index 
                ? FontWeight.bold 
                : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    ));
  }
}