import 'package:flutter_app/app/controller/lifterlms/course_detail_controller.dart';
import 'package:get/get.dart';

class CourseDetailBinding extends Bindings {
  @override
  void dependencies() async {
    Get.lazyPut<CourseDetailController>(
      () => CourseDetailController(),
      fenix: true
    );
  }
}
