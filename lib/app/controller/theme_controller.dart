import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController {
  static const String THEME_KEY = 'theme_mode';
  
  final _isDarkMode = false.obs;
  bool get isDarkMode => _isDarkMode.value;
  
  late SharedPreferences _prefs;
  
  @override
  void onInit() {
    super.onInit();
    _loadThemeFromPrefs();
  }
  
  Future<void> _loadThemeFromPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode.value = _prefs.getBool(THEME_KEY) ?? false;
    _updateTheme();
  }
  
  Future<void> toggleTheme() async {
    _isDarkMode.value = !_isDarkMode.value;
    await _prefs.setBool(THEME_KEY, _isDarkMode.value);
    _updateTheme();
  }
  
  Future<void> setDarkMode(bool value) async {
    _isDarkMode.value = value;
    await _prefs.setBool(THEME_KEY, value);
    _updateTheme();
  }
  
  void _updateTheme() {
    Get.changeThemeMode(_isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }
  
  ThemeMode get themeMode => _isDarkMode.value ? ThemeMode.dark : ThemeMode.light;
}