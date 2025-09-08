import 'package:flutter_app/app/controller/lifterlms/payment_controller.dart';
import 'package:get/get.dart';

class PaymentBinding extends Bindings {
  @override
  void dependencies() async {
    Get.lazyPut<PaymentController>(
      () => PaymentController(),
      fenix: true
    );
  }
}
