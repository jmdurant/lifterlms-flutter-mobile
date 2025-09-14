import 'dart:math' as math;
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/controller/lifterlms/courses_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/home_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/wishlist_controller.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/view/components/item-course.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:get/get.dart';
import 'package:indexed/indexed.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({Key? key}) : super(key: key);

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void onLogin() {
    Future.delayed(Duration.zero, () {
      Get.toNamed(AppRouter.getLoginRoute());
    });
  }

  final WishlistController wishlistController = Get.find<WishlistController>();
  final HomeController homeController = Get.find<HomeController>();
  final CoursesController courseController = Get.find<CoursesController>();
  var screenWidth =
      (window.physicalSize.shortestSide / window.devicePixelRatio);
  var screenHeight =
      (window.physicalSize.longestSide / window.devicePixelRatio);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<WishlistController>(builder: (value) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
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
                if (wishlistController.lmsService.isLoggedIn &&
                    wishlistController.wishlistCourses.isEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 50),
                    child: Text(
                      tr(LocaleKeys.dataNotFound),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
                !wishlistController.lmsService.isLoggedIn
                    ? Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                tr(LocaleKeys.needLogin),
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(
                                height: 20,
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 30),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                onPressed: onLogin,
                                child: Text(
                                  tr(LocaleKeys.login),
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => wishlistController.refreshWishlist(),
                          child: ListView.builder(
                              controller: wishlistController.scrollController,
                              itemCount: wishlistController.wishlistCourses.length +
                                  (wishlistController.isLoadingMore.value ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == wishlistController.wishlistCourses.length) {
                                  return const Center(
                                      child: SizedBox(
                                    width: 20.0,
                                    height: 20.0,
                                          child: CircularProgressIndicator(),
                                  ));
                                } else if (index < wishlistController.wishlistCourses.length) {
                                  final course = wishlistController.wishlistCourses[index];
                                  return ItemCourse(
                                      item: course,
                                      courseDetailParser: Get.find(),
                                      onToggleWishlist: () async => {
                                            await wishlistController.removeFromWishlist(
                                                course.id),
                                            // Refresh other screens if needed
                                            if (homeController.onInit != null)
                                              homeController.onInit(),
                                            if (courseController.onInit != null)
                                              courseController.onInit(),
                                          },
                                    hideCategory: true,
                                          );
                                } else {
                                  return Container();
                                }
                              }),
                        ),
                      ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
