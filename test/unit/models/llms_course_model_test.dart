import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';

import '../../helpers/mock_data.dart';

void main() {
  group('LLMSCourseModel', () {
    group('fromJson() with complete data', () {
      late LLMSCourseModel course;

      setUp(() {
        course = LLMSCourseModel.fromJson(MockData.sampleCourseJson());
      });

      test('parses id', () {
        expect(course.id, 101);
      });

      test('extracts rendered title', () {
        expect(course.title, 'Introduction to Flutter');
      });

      test('extracts rendered content', () {
        expect(course.content, contains('Full course content'));
      });

      test('parses pricing fields', () {
        expect(course.price, 49.99);
        expect(course.regularPrice, 49.99);
        expect(course.priceType, 'paid');
      });

      test('parses category and tag lists', () {
        expect(course.categories, [1, 2]);
        expect(course.tags, [10]);
      });

      test('parses dates', () {
        expect(course.dateCreated.year, 2025);
        expect(course.dateCreated.month, 1);
      });

      test('parses instructor list', () {
        expect(course.instructors, isNotEmpty);
        expect(course.instructors.first.name, 'Jane Doe');
      });

      test('parses boolean flags', () {
        expect(course.purchasable, isTrue);
        expect(course.hasAccessPlans, isTrue);
        expect(course.hasCertificate, isTrue);
        expect(course.capacityEnabled, isFalse);
      });

      test('parses accessPlans', () {
        expect(course.accessPlans, [201, 202]);
      });

      test('parses passing percentage', () {
        expect(course.passingPercentage, 80.0);
      });
    });

    group('fromJson() with minimal / missing fields', () {
      late LLMSCourseModel course;

      setUp(() {
        course = LLMSCourseModel.fromJson(MockData.minimalCourseJson());
      });

      test('falls back to defaults for missing fields', () {
        expect(course.id, 1);
        expect(course.title, 'Minimal Course');
        expect(course.content, '');
        expect(course.excerpt, '');
        expect(course.slug, '');
        expect(course.status, 'publish');
        expect(course.price, 0.0);
        expect(course.priceType, 'free');
        expect(course.categories, isEmpty);
        expect(course.instructors, isEmpty);
        expect(course.sections, isNull);
      });

      test('nullable fields are null', () {
        expect(course.prerequisite, isNull);
        expect(course.videoEmbed, isNull);
        expect(course.accessOpensDate, isNull);
      });
    });

    group('fromJson() with string id', () {
      test('parses string id to int', () {
        final json = MockData.sampleCourseJson();
        json['id'] = '999';
        final course = LLMSCourseModel.fromJson(json);
        expect(course.id, 999);
      });
    });

    group('computed properties', () {
      test('isFree is true when priceType is free', () {
        final course = LLMSCourseModel.fromJson(
          MockData.sampleCourseJson(priceType: 'free', price: 0),
        );
        expect(course.isFree, isTrue);
        expect(course.isPaid, isFalse);
      });

      test('isPaid is true when priceType is paid and price > 0', () {
        final course = LLMSCourseModel.fromJson(
          MockData.sampleCourseJson(priceType: 'paid', price: 29.99),
        );
        expect(course.isPaid, isTrue);
        expect(course.isFree, isFalse);
      });

      test('isMembersOnly is true when priceType is members', () {
        final course = LLMSCourseModel.fromJson(
          MockData.sampleCourseJson(priceType: 'members'),
        );
        expect(course.isMembersOnly, isTrue);
      });

      test('hasPrerequisite is false when prerequisite is null', () {
        final course = LLMSCourseModel.fromJson(MockData.sampleCourseJson());
        expect(course.hasPrerequisite, isFalse);
      });

      test('isEnrollmentOpen is true when enrollmentPeriod is false', () {
        final course = LLMSCourseModel.fromJson(MockData.sampleCourseJson());
        expect(course.isEnrollmentOpen, isTrue);
      });

      test('hasCapacity is true when capacityEnabled is false', () {
        final course = LLMSCourseModel.fromJson(MockData.sampleCourseJson());
        expect(course.hasCapacity, isTrue);
      });
    });

    group('toJson()', () {
      test('round-trips without data loss', () {
        final original = LLMSCourseModel.fromJson(MockData.sampleCourseJson());
        final json = original.toJson();
        final restored = LLMSCourseModel.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.title, original.title);
        expect(restored.price, original.price);
        expect(restored.priceType, original.priceType);
        expect(restored.slug, original.slug);
      });
    });
  });
}
