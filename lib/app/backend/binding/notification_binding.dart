import 'package:flutter_app/app/controller/lifterlms/notification_controller.dart';
import 'package:get/get.dart';

class NotificationBinding extends Bindings {
  @override
  void dependencies() async {
    Get.lazyPut<NotificationController>(
      () => NotificationController(),
      fenix: true
    );
  }
}
