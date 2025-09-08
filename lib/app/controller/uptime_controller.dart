import 'dart:async';
import 'package:get/get.dart';

class UptimeController extends GetxController {
  var timeElapsed = 0.obs;
  late Timer _timer;

  @override
  void onInit() {
    super.onInit();
    startTimer();  // Start timer when controller is initialized
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      timeElapsed++;
    });
  }

  void stopTimer() {
    _timer.cancel();
  }

  @override
  void onClose() {
    _timer.cancel();
    super.onClose();
  }
}
