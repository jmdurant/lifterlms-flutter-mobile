import 'package:get/get.dart';

class CourseStoreController extends GetxController {
  final Rxn<dynamic> detail = Rxn<dynamic>();

  void setDetail(value) {
    detail.value = value;
  }
}
