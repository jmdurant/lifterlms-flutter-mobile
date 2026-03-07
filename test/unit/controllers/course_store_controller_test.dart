import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/app/controller/course_store_controller.dart';

import '../../helpers/test_helpers.dart';
import '../../helpers/mock_data.dart';

void main() {
  group('CourseStoreController', () {
    useGetxTestLifecycle();

    test('initial detail value is null', () {
      final controller = CourseStoreController();
      expect(controller.detail.value, isNull);
    });

    test('setDetail() updates detail.value', () {
      final controller = CourseStoreController();
      final courseData = MockData.sampleCourseJson();

      controller.setDetail(courseData);

      expect(controller.detail.value, isNotNull);
      expect(controller.detail.value, isA<Map<String, dynamic>>());
      expect(controller.detail.value['id'], 101);
    });

    test('setDetail() can be set to null', () {
      final controller = CourseStoreController();
      controller.setDetail({'id': 1});
      expect(controller.detail.value, isNotNull);

      controller.setDetail(null);
      expect(controller.detail.value, isNull);
    });

    test('setDetail() can be called with different types', () {
      final controller = CourseStoreController();

      controller.setDetail('a string value');
      expect(controller.detail.value, 'a string value');

      controller.setDetail(42);
      expect(controller.detail.value, 42);

      controller.setDetail([1, 2, 3]);
      expect(controller.detail.value, [1, 2, 3]);
    });
  });
}
