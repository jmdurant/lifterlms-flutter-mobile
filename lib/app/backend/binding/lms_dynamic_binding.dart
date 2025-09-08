import 'package:get/get.dart';

// LifterLMS Controllers
import 'package:flutter_app/app/controller/lifterlms/home_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/courses_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/course_detail_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/learning_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/wishlist_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/my_courses_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/login_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/register_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/search_course_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/instructor_detail_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/profile_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/my_profile_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/payment_controller.dart';

/// Dynamic binding that loads LifterLMS controllers
/// This file is kept for backward compatibility but now only loads LifterLMS controllers
class LMSDynamicBinding extends Bindings {
  @override
  void dependencies() {
    _loadLifterLMSControllers();
  }
  
  /// Load LifterLMS controllers
  void _loadLifterLMSControllers() {
    // Core controllers
    Get.lazyPut(() => HomeController());
    Get.lazyPut(() => CoursesController());
    Get.lazyPut(() => CourseDetailController());
    Get.lazyPut(() => LearningController());
    Get.lazyPut(() => WishlistController());
    Get.lazyPut(() => MyCoursesController());
    
    // Auth controllers
    Get.lazyPut(() => LoginController());
    Get.lazyPut(() => RegisterController());
    
    // Search & Instructor
    Get.lazyPut(() => SearchCourseController());
    Get.lazyPut(() => InstructorDetailController());
    
    // Profile
    Get.lazyPut(() => ProfileController());
    Get.lazyPut(() => MyProfileController());
    
    // Payment
    Get.lazyPut(() => PaymentController());
  }
}