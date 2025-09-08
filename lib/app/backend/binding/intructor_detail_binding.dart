import 'package:flutter_app/app/controller/lifterlms/instructor_detail_controller.dart';
import 'package:get/get.dart';

class InstructorDetailBinding extends Bindings {
  @override
  void dependencies() async {
    Get.lazyPut<InstructorDetailController>(
      () => InstructorDetailController(),
      fenix: true
    );
  }
}
