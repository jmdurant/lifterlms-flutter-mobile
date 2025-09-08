import 'package:flutter_app/app/controller/lifterlms/courses_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/home_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/my_courses_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/my_profile_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/wishlist_controller.dart';
import 'package:get/get.dart';

import '../../controller/tabs_controller.dart';

class TabsBinding extends Bindings {
  @override
  void dependencies() async {
    Get.lazyPut(() => TabControllerX(),fenix: true);
    Get.lazyPut(() => HomeController());
    Get.lazyPut(() => CoursesController());
    Get.lazyPut(() => WishlistController());
    Get.lazyPut(() => MyCoursesController());
    Get.lazyPut(() => MyProfileController());
  }
}
