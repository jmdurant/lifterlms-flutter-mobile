import 'package:flutter_app/app/controller/lifterlms/learning_controller.dart';
import 'package:get/get.dart';

class LearningBinding extends Bindings {
  @override
  void dependencies() async {
    Get.lazyPut<LearningController>(
      () => LearningController(),
      fenix: true
    );
  }
}
