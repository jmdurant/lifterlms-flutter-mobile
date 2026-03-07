import 'package:shared_preferences/shared_preferences.dart';

/// Note: Auth tokens (JWT, access tokens) should NOT be stored via
/// SharedPreferencesManager. Use [SecureStorageService] from
/// 'package:flutter_app/app/util/secure_storage.dart' instead.
class SharedPreferencesManager {
  SharedPreferences? sharedPreferences;

  @Deprecated('Use SecureStorageService.saveToken / getToken instead. '
      'Auth tokens must not be stored in plaintext SharedPreferences.')
  static const String keyAccessToken = 'accessToken';
  static const String keyUserData = 'user_data';
  static const String keyRole = 'user_role';
  static const String keyFcmToken = 'fcm_token';

  SharedPreferencesManager({required this.sharedPreferences});

  Future<bool>? putBool(String key, bool value) =>
      sharedPreferences?.setBool(key, value);

  bool getBool(String key) => sharedPreferences?.getBool(key) ?? false;

  Future<bool>? putDouble(String key, double value) =>
      sharedPreferences?.setDouble(key, value);

  double? getDouble(String key) => sharedPreferences?.getDouble(key);

  Future<bool>? putInt(String key, int value) =>
      sharedPreferences?.setInt(key, value);

  int? getInt(String key) => sharedPreferences?.getInt(key);

  Future<bool>? putString(String key, String value) =>
      sharedPreferences?.setString(key, value);

  String? getString(String key) => sharedPreferences?.getString(key);

  Future<bool>? putStringList(String key, List<String> value) =>
      sharedPreferences?.setStringList(key, value);

  Future<bool>? putCartString(String key, var value) =>
      sharedPreferences?.setStringList(key, value);

  List<String>? getStringList(String key) =>
      sharedPreferences?.getStringList(key);

  bool? isKeyExists(String key) => sharedPreferences?.containsKey(key);

  Future<bool>? clearKey(String key) => sharedPreferences?.remove(key);

  Future<bool>? clearAll() => sharedPreferences?.clear();
}
