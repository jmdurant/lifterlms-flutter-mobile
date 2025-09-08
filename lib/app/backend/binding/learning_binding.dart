import 'package:flutter_app/app/controller/lifterlms/learning_controller.dart';
import 'package:get/get.dart';

class LearningBinding extends Bindings {
  @override
  void dependencies() async {
    // Fresh controller per route visit for correct course context
    Get.create<LearningController>(
      () => LearningController(),
      permanent: false,
    );
  }
}
