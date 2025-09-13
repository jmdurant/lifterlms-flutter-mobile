import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/controller/lifterlms/instructor_detail_controller.dart';
import 'package:flutter_app/app/view/components/item-course.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:get/get.dart';
import 'package:indexed/indexed.dart';
import 'package:url_launcher/url_launcher.dart';

class InstructorDetailScreen extends StatefulWidget {
  const InstructorDetailScreen({Key? key}) : super(key: key);

  @override
  State<InstructorDetailScreen> createState() => _InstructorDetailScreenState();
}

class _InstructorDetailScreenState extends State<InstructorDetailScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  var screenWidth =
      (window.physicalSize.shortestSide / window.devicePixelRatio);
  var screenHeight =
      (window.physicalSize.longestSide / window.devicePixelRatio);
  
  @override
  void initState() {
    super.initState();
    // Initialize the controller with the instructor ID
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Get.find<InstructorDetailController>();
      final args = Get.arguments;
      int instructorId = 0;
      
      if (args != null) {
        if (args is Map && args['id'] != null) {
          instructorId = args['id'];
        } else if (args is int) {
          instructorId = args;
        }
      }
      
      if (instructorId != 0) {
        controller.initializeWithInstructor(instructorId);
      }
    });
  }

  void _launchUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<InstructorDetailController>(builder: (value) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        drawerEnableOpenDragGesture: false,
        body: Stack(
          children: <Widget>[
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
                  height: 80.0,
                  width: screenWidth,
                  // color: Colors.blue,
                  padding: const EdgeInsets.fromLTRB(0, 40, 0, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        // width: 40,
                        child: IconButton(
                          onPressed: () {
                            Get.back();
                          },
                          icon: const Icon(Icons.arrow_back),
                          color: Colors.grey[900],
                          iconSize: 24,
                        ),
                      ),
                      Text(
                        tr(LocaleKeys.instructorScreen_title),
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
                value.isLoading.value
                    ? Center(child: CircularProgressIndicator())
                    : value.instructor.value == null
                        ? Center(child: Text('Instructor not found'))
                        : Container(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 5,
                            ),
                            value.instructor.value?.avatarUrl != null &&
                                    value.instructor.value!.avatarUrl.isNotEmpty &&
                                    value.instructor.value!.avatarUrl != 'null'
                                ? Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        image: DecorationImage(
                                          fit: BoxFit.cover,
                                          image: NetworkImage(
                                              value.instructor.value!.avatarUrl),
                                        )))
                                : const CircleAvatar(
                                    radius: 30,
                                    backgroundImage: AssetImage(
                                      'assets/images/default-avatar.png',
                                    ),
                                  ),
                            SizedBox(
                              width: 20,
                            ),
                            Expanded(
                                flex: 1,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 12,
                                    ),
                                    Text(value.instructor.value?.name ?? 'Unknown',
                                        style: const TextStyle(
                                          fontFamily: 'Medium',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        )),
                                    if (value.instructor.value?.description != null &&
                                        value.instructor.value!.description.isNotEmpty)
                                      Text(value.instructor.value!.description,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 12,
                                            color: Colors.grey,
                                          )),
                                  ],
                                ))
                          ],
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Row(
                          children: [
                            if (value.socialLinks.containsKey('facebook') &&
                                value.socialLinks['facebook']?.isNotEmpty == true) ...[
                              GestureDetector(
                                  child: Icon(
                                    FeatherIcons.facebook,
                                    size: 16,
                                    color: Colors.grey.shade800,
                                  ),
                                  onTap: () => _launchUrl(value.socialLinks['facebook']!)),
                              SizedBox(width: 10),
                            ],
                            if (value.socialLinks.containsKey('twitter') &&
                                value.socialLinks['twitter']?.isNotEmpty == true) ...[
                              GestureDetector(
                                  child: Icon(
                                    FeatherIcons.twitter,
                                    size: 16,
                                    color: Colors.grey.shade800,
                                  ),
                                  onTap: () => _launchUrl(value.socialLinks['twitter']!)),
                              SizedBox(width: 10),
                            ],
                            if (value.socialLinks.containsKey('youtube') &&
                                value.socialLinks['youtube']?.isNotEmpty == true) ...[
                              GestureDetector(
                                  child: Icon(
                                    FeatherIcons.youtube,
                                    size: 16,
                                    color: Colors.grey.shade800,
                                  ),
                                  onTap: () => _launchUrl(value.socialLinks['youtube']!)),
                            ],
                            if (value.socialLinks.containsKey('website') &&
                                value.socialLinks['website']?.isNotEmpty == true) ...[
                              GestureDetector(
                                  child: Icon(
                                    FeatherIcons.globe,
                                    size: 16,
                                    color: Colors.grey.shade800,
                                  ),
                                  onTap: () => _launchUrl(value.socialLinks['website']!)),
                            ],
                          ],
                        ),
                        SizedBox(
                          height: 16,
                        ),
                        if (value.instructor.value != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  "${value.instructor.value!.courseCount} " +
                                      tr(LocaleKeys.home_countCourse),
                                  style: TextStyle(
                                    fontFamily: 'medium',
                                    fontSize: 15,
                                    color: Colors.black,
                                  )),
                            ],
                          ),
                      ]),
                ),
                SizedBox(height: 15,),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => value.refreshInstructor(),
                    child: ListView.builder(
                        controller: value.scrollController,
                        itemCount: value.instructorCourses.length +
                            (value.isLoadingCourses.value ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == value.instructorCourses.length) {
                            return const Center(
                                child: SizedBox(
                              width: 20.0,
                              height: 20.0,
                                  child: CircularProgressIndicator(),
                            ));
                          } else if (index < value.instructorCourses.length) {
                            return Container(
                              margin: EdgeInsetsDirectional.only(bottom: 20),
                              child: ItemCourse(
                                item: value.instructorCourses[index],
                                courseDetailParser: Get.find(),
                                onToggleWishlist: () {
                                  // Wishlist not implemented in LifterLMS
                                },
                              ),
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
