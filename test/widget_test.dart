// Basic smoke test that verifies key classes can be instantiated
// without requiring Firebase or other platform services.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/app/backend/models/response_v2.dart';
import 'package:flutter_app/app/backend/models/user_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_lesson_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_category_model.dart';
import 'package:flutter_app/app/controller/course_store_controller.dart';

import 'helpers/mock_data.dart';

void main() {
  group('Smoke test - class instantiation', () {
    test('ResponseV2 can be constructed with named parameters', () {
      final response = ResponseV2(
        status: 'success',
        message: 'ok',
        data: [],
      );
      expect(response.status, 'success');
      expect(response.message, 'ok');
    });

    test('UserModel can be constructed with named parameters', () {
      final user = UserModel(
        user_id: 1,
        user_login: 'test',
        user_email: 'test@example.com',
        user_display_name: 'Test User',
      );
      expect(user.user_id, 1);
      expect(user.user_login, 'test');
    });

    test('LLMSCourseModel.fromJson parses sample data', () {
      final course = LLMSCourseModel.fromJson(MockData.sampleCourseJson());
      expect(course.id, 101);
      expect(course.title, 'Introduction to Flutter');
    });

    test('LLMSLessonModel.fromJson parses sample data', () {
      final lesson = LLMSLessonModel.fromJson(MockData.sampleLessonJson());
      expect(lesson.id, 501);
      expect(lesson.title, 'Getting Started with Dart');
    });

    test('LLMSCategoryModel.fromJson parses sample data', () {
      final category =
          LLMSCategoryModel.fromJson(MockData.sampleCategoryJson());
      expect(category.id, 5);
      expect(category.name, 'Programming');
    });

    test('CourseStoreController can be instantiated', () {
      final controller = CourseStoreController();
      expect(controller.detail.value, isNull);
    });
  });
}
