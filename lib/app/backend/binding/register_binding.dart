import 'package:flutter_app/app/backend/binding/lms_dynamic_binding.dart';
import 'package:get/get.dart';

class RegisterBinding extends Bindings {
  @override
  void dependencies() async {
    // Controllers are already registered in LMSDynamicBinding
    // This binding just ensures they're available when needed
    LMSDynamicBinding().dependencies();
  }
}
