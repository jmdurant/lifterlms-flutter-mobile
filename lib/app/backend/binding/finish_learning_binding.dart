import 'package:flutter_app/app/controller/lifterlms/finish_learning_controller.dart';
import 'package:get/get.dart';

class FinishLearningBinding extends Bindings {
  @override
  void dependencies() async {
    Get.lazyPut<FinishLearningController>(
      () => FinishLearningController(),
      fenix: true
    );
  }
}
