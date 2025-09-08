import 'package:flutter_app/app/controller/lifterlms/forgot_password_controller.dart';
import 'package:get/get.dart';

class ForgotPasswordBinding extends Bindings {
  @override
  void dependencies() async {
    Get.lazyPut<ForgotPasswordController>(
      () => ForgotPasswordController(),
      fenix: true
    );
  }
}
