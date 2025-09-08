import 'package:flutter_app/app/controller/lifterlms/course_detail_controller.dart';
import 'package:get/get.dart';

class CourseDetailBinding extends Bindings {
  @override
  void dependencies() async {
    // Create a fresh instance per navigation to avoid stale course state
    Get.create<CourseDetailController>(
      () => CourseDetailController(),
      permanent: false,
    );
  }
}
