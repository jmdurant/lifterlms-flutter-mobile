import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/app/backend/models/user_model.dart';

import '../../helpers/mock_data.dart';

void main() {
  group('UserModel', () {
    group('fromJson()', () {
      test('parses valid user JSON', () {
        final user = UserModel.fromJson(MockData.sampleUserJson());

        expect(user.user_id, 42);
        expect(user.user_login, 'johndoe');
        expect(user.user_email, 'john@example.com');
        expect(user.user_display_name, 'John Doe');
      });

      test('parses user_id when provided as string', () {
        final json = MockData.sampleUserJson();
        json['user_id'] = '99';
        final user = UserModel.fromJson(json);

        expect(user.user_id, 99);
      });

      test('handles custom values', () {
        final user = UserModel.fromJson(MockData.sampleUserJson(
          userId: 7,
          login: 'admin',
          email: 'admin@site.com',
          displayName: 'Site Admin',
        ));

        expect(user.user_id, 7);
        expect(user.user_login, 'admin');
        expect(user.user_email, 'admin@site.com');
        expect(user.user_display_name, 'Site Admin');
      });
    });

    group('toJson()', () {
      test('produces correct map', () {
        final user = UserModel(
          user_id: 10,
          user_login: 'alice',
          user_email: 'alice@example.com',
          user_display_name: 'Alice',
        );
        final json = user.toJson();

        expect(json['user_id'], 10);
        expect(json['user_login'], 'alice');
        expect(json['user_email'], 'alice@example.com');
        expect(json['user_display_name'], 'Alice');
      });

      test('round-trips correctly', () {
        final original = UserModel.fromJson(MockData.sampleUserJson());
        final json = original.toJson();
        // user_id comes back as int from toJson, which int.parse handles
        json['user_id'] = json['user_id'].toString();
        final restored = UserModel.fromJson(json);

        expect(restored.user_id, original.user_id);
        expect(restored.user_login, original.user_login);
        expect(restored.user_email, original.user_email);
        expect(restored.user_display_name, original.user_display_name);
      });
    });

    group('constructor with null fields', () {
      test('all fields default to null', () {
        final user = UserModel();
        expect(user.user_id, isNull);
        expect(user.user_login, isNull);
        expect(user.user_email, isNull);
        expect(user.user_display_name, isNull);
      });
    });
  });
}
