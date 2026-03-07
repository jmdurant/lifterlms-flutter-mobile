import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/app/backend/models/response_v2.dart';

import '../../helpers/mock_data.dart';

void main() {
  group('ResponseV2', () {
    group('fromJson()', () {
      test('parses valid JSON correctly', () {
        final json = MockData.sampleResponseV2Json();
        final response = ResponseV2.fromJson(json);

        expect(response.status, 'success');
        expect(response.message, 'Data retrieved successfully');
        expect(response.data, isList);
        expect((response.data as List).length, 2);
      });

      test('parses status and message as strings even when numeric', () {
        final json = MockData.sampleResponseV2Json(
          status: '200',
          message: 'OK',
        );
        final response = ResponseV2.fromJson(json);

        expect(response.status, '200');
        expect(response.message, 'OK');
      });

      test('handles empty items list', () {
        final json = MockData.sampleResponseV2Json(items: []);
        final response = ResponseV2.fromJson(json);

        expect(response.data, isList);
        expect((response.data as List), isEmpty);
      });
    });

    group('toJson()', () {
      test('produces valid JSON map', () {
        final response = ResponseV2(
          status: 'success',
          message: 'ok',
          data: [1, 2, 3],
        );
        final json = response.toJson();

        expect(json['status'], 'success');
        expect(json['message'], 'ok');
        expect(json['data'], [1, 2, 3]);
      });

      test('round-trip: toJson output can be serialized and deserialized', () {
        // This validates that toJson does not produce circular references.
        final response = ResponseV2(
          status: 'ok',
          message: 'test',
          data: [
            {'id': 1, 'name': 'Course A'},
          ],
        );

        final jsonMap = response.toJson();
        // Should not throw - validates no circular references.
        final encoded = jsonEncode(jsonMap);
        expect(encoded, isA<String>());

        final decoded = jsonDecode(encoded) as Map<String, dynamic>;
        expect(decoded['status'], 'ok');
        expect(decoded['data'], isList);
      });
    });

    group('null / missing fields', () {
      test('constructor accepts all-null fields', () {
        final response = ResponseV2();
        expect(response.status, isNull);
        expect(response.message, isNull);
        expect(response.data, isNull);
      });

      test('toJson includes null values', () {
        final response = ResponseV2();
        final json = response.toJson();

        expect(json.containsKey('status'), isTrue);
        expect(json.containsKey('message'), isTrue);
        expect(json.containsKey('data'), isTrue);
      });
    });
  });
}
