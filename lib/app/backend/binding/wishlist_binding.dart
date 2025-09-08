import 'package:flutter_app/app/controller/lifterlms/wishlist_controller.dart';
import 'package:get/get.dart';

class WishlistBinding extends Bindings {
  @override
  void dependencies() async {
    Get.lazyPut<WishlistController>(
      () => WishlistController(),
      fenix: true
    );
  }
}
