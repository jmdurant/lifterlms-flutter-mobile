import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _passwordKey = 'saved_password';

  static Future<void> saveToken(String token) async => await _storage.write(key: _tokenKey, value: token);
  static Future<String?> getToken() async => await _storage.read(key: _tokenKey);
  static Future<void> deleteToken() async => await _storage.delete(key: _tokenKey);

  static Future<void> savePassword(String password) async => await _storage.write(key: _passwordKey, value: password);
  static Future<String?> getPassword() async => await _storage.read(key: _passwordKey);
  static Future<void> deletePassword() async => await _storage.delete(key: _passwordKey);

  static Future<void> clearAll() async => await _storage.deleteAll();
}
