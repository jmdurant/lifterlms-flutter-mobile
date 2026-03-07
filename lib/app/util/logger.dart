import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

class AppLogger {
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      dev.log(message, name: tag ?? 'App');
    }
  }

  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      dev.log(message, name: tag ?? 'App', error: error, stackTrace: stackTrace);
    }
  }

  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      dev.log(message, name: tag ?? 'App');
    }
  }
}
