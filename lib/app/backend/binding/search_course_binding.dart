import 'package:flutter_app/app/controller/lifterlms/search_course_controller.dart';
import 'package:get/get.dart';

class SearchCourseBinding extends Bindings {
  @override
  void dependencies() async {
    Get.lazyPut<SearchCourseController>(
      () => SearchCourseController(),
      fenix: true
    );
  }
}
