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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawerEnableOpenDragGesture: false,
        body: Stack(
          children: <Widget>[
            Positioned(
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
            Column(
              children: <Widget>[
                // Add header like other screens
                Container(
                  padding: EdgeInsets.fromLTRB(
                      0, MediaQuery.of(context).viewPadding.top + 10, 0, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Favorites',
                        style: TextStyle(
                          fontFamily: 'Poppins-Medium',
                          fontWeight: FontWeight.w500,
                          fontSize: 24,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                if (value.lmsService.isLoggedIn &&
                    value.wishlistCourses.isEmpty &&
                    !value.isLoading.value &&
                    !value.hasError.value)
                  Container(
                    margin: EdgeInsets.only(top: 50),
                    child: Text(
                      tr(LocaleKeys.dataNotFound),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
                !value.lmsService.isLoggedIn
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
                    : value.hasError.value
                    ? Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.extension_off,
                                  size: 60,
                                  color: Colors.grey.shade400,
                                ),
                                SizedBox(height: 20),
                                Text(
                                  'Unable to connect to companion WordPress extension.\n\nPlease install WordPress extension to utilize wishlist and favorites features.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                ),
                                SizedBox(height: 20),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 30),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  onPressed: () => value.refreshWishlist(),
                                  child: Text(
                                    'Retry',
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
                        ),
                      )
                    : value.isLoading.value && value.wishlistCourses.isEmpty
                    ? Expanded(
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => value.refreshWishlist(),
                          child: ListView.builder(
                              controller: value.scrollController,
                              itemCount: value.wishlistCourses.length +
                                  (value.isLoadingMore.value ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == value.wishlistCourses.length) {
                                  return const Center(
                                      child: SizedBox(
                                    width: 20.0,
                                    height: 20.0,
                                          child: CircularProgressIndicator(),
                                  ));
                                } else if (index < value.wishlistCourses.length) {
                                  final course = value.wishlistCourses[index];
                                  return ItemCourse(
                                      item: course,
                                      courseDetailParser: Get.find(),
                                      onToggleWishlist: () async => {
                                            await value.removeFromWishlist(
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
