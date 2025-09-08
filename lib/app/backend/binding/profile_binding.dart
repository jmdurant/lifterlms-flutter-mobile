import 'package:flutter_app/app/controller/lifterlms/profile_controller.dart';
import 'package:get/get.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() async {
    Get.lazyPut<ProfileController>(
      () => ProfileController(),
      fenix: true
    );
  }
}