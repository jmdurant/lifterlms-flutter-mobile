/// Common test utilities and setup helpers.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Sets up a clean GetX test environment.
///
/// Call this in setUp() for any test that uses GetX controllers.
/// It resets the GetX dependency injection container so each test
/// starts with a clean slate.
void setupGetxTestEnvironment() {
  // Reset GetX so controllers from previous tests don't leak.
  Get.reset();
}

/// Tears down the GetX test environment.
///
/// Call this in tearDown() to clean up after tests that registered
/// GetX controllers or services.
void teardownGetxTestEnvironment() {
  Get.reset();
}

/// Convenience wrapper that registers setUp/tearDown for GetX tests.
///
/// Usage:
/// ```dart
/// void main() {
///   useGetxTestLifecycle();
///   // ... your tests ...
/// }
/// ```
void useGetxTestLifecycle() {
  setUp(setupGetxTestEnvironment);
  tearDown(teardownGetxTestEnvironment);
}
