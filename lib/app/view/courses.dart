import 'dart:ui';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/controller/lifterlms/courses_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/home_controller.dart';
import 'package:flutter_app/app/view/components/categories_course.dart';
import 'package:flutter_app/app/view/components/item-course.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:get/get.dart';
import 'package:indexed/indexed.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({Key? key}) : super(key: key);

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  var screenWidth =
      (window.physicalSize.shortestSide / window.devicePixelRatio);
  var screenHeight =
      (window.physicalSize.longestSide / window.devicePixelRatio);
  final HomeController homeController = Get.find<HomeController>();

  @override
  Widget build(BuildContext context) {
    double top = MediaQuery.of(context).viewPadding.top;
    return GetBuilder<CoursesController>(builder: (controller) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawerEnableOpenDragGesture: false,
        body: Stack(
          children: <Widget>[
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
            Column(
              children: <Widget>[
                SizedBox(height: math.max(20, MediaQuery.of(context).viewPadding.top)),
                Obx(() => Column(
                  children: [
                    if (controller.searchQuery.value.isNotEmpty)
                      Container(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(tr(LocaleKeys.courses_searching) +
                                " " +
                                controller.searchQuery.value),
                            GestureDetector(
                              onTap: () {
                                controller.searchQuery.value = "";
                                controller.getCourses(isRefresh: true);
                              },
                              child: Icon(
                                Icons.close_outlined,
                                size: 20,
                              ),
                            )
                          ],
                        ),
                      ),
                    // Filter dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Search field
                          Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(context).dividerColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search courses...',
                                  prefixIcon: Icon(Icons.search, size: 20),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                onSubmitted: (value) {
                                  controller.searchQuery.value = value;
                                  controller.getCourses(isRefresh: true);
                                },
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          // Sort dropdown
                          Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).unselectedWidgetColor.withOpacity(0.5),
                                  spreadRadius: 1,
                                  blurRadius: 1,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: DropdownButton<String>(
                              value: controller.sortBy.value,
                              hint: Text('Sort'),
                              underline: Container(),
                              icon: Icon(Icons.arrow_drop_down, size: 20),
                              onChanged: (String? value) {
                                if (value != null) {
                                  controller.sortBy.value = value;
                                  controller.getCourses(isRefresh: true);
                                }
                              },
                              items: ['date_created', 'title', 'menu_order'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value == 'date_created' ? 'Date' :
                                    value == 'title' ? 'Title' : 'Menu Order',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )),
                // Categories - disabled for LifterLMS (different model structure)
                // if (controller.categoriesList.isNotEmpty)
                //   CategoriesCourse(categoriesList: controller.categoriesList),
                SizedBox(height: 4),
                // Courses list
                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value && controller.coursesList.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    
                    if (controller.hasError.value) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(controller.errorMessage.value),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => controller.getCourses(isRefresh: true),
                              child: Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    if (controller.coursesList.isEmpty) {
                      return Center(
                        child: Text(
                          tr(LocaleKeys.dataNotFound),
                          style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                        ),
                      );
                    }
                    
                    return RefreshIndicator(
                      onRefresh: () => controller.getCourses(isRefresh: true),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        controller: controller.scrollController,
                        itemCount: controller.coursesList.length +
                            (controller.isLoadingMore.value ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == controller.coursesList.length) {
                            return const Center(
                              child: SizedBox(
                                width: 20.0,
                                height: 20.0,
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          
                          return Container(
                            margin: EdgeInsetsDirectional.only(
                              top: index == 0 ? 0 : 0,
                              bottom: 20,
                            ),
                            child: ItemCourse(
                              item: controller.coursesList[index],
                              onToggleWishlist: () async {
                                // Wishlist functionality removed - not in controller
                                homeController.refreshScreen();
                              },
                              courseDetailParser: Get.find(),
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}