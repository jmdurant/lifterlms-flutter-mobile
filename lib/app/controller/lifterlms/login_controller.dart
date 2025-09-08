import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/controller/lifterlms/my_courses_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/notification_controller.dart';
import 'package:flutter_app/app/helper/dialog_helper.dart';
import 'package:flutter_app/app/util/toast.dart';
import 'package:get/get.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helper/router.dart';

class LoginController extends GetxController implements GetxService {
  final LMSService lmsService = LMSService.to;
  late SharedPreferences prefs;
  
  // Controllers
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  
  // Observable states
  final RxBool isLoading = false.obs;
  final RxBool rememberMe = false.obs;
  final RxBool obscurePassword = true.obs;
  
  // User data
  final Rx<Map<String, dynamic>> userData = Rx<Map<String, dynamic>>({});
  
  @override
  void onInit() {
    super.onInit();
    initPreferences();
    checkSavedCredentials();
  }
  
  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }
  
  /// Initialize SharedPreferences
  Future<void> initPreferences() async {
    prefs = await SharedPreferences.getInstance();
  }
  
  /// Check for saved credentials
  Future<void> checkSavedCredentials() async {
    await initPreferences();
    
    if (prefs.getBool('remember_me') ?? false) {
      usernameController.text = prefs.getString('saved_username') ?? '';
      passwordController.text = prefs.getString('saved_password') ?? '';
      rememberMe.value = true;
    }
  }
  
  /// Toggle password visibility
  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }
  
  /// Toggle remember me
  void toggleRememberMe(bool value) {
    rememberMe.value = value;
  }
  
  /// Validate login form
  bool validateForm() {
    if (usernameController.text.trim().isEmpty) {
      showToast("Username is required", isError: true);
      return false;
    }
    
    if (passwordController.text.isEmpty) {
      showToast("Password is required", isError: true);
      return false;
    }
    
    if (passwordController.text.length < 6) {
      showToast("Password must be at least 6 characters", isError: true);
      return false;
    }
    
    return true;
  }
  
  /// Login user
  Future<void> login() async {
    if (!validateForm()) return;
    
    try {
      isLoading.value = true;
      DialogHelper.showLoading();
      
      final username = usernameController.text.trim();
      final password = passwordController.text;
      
      // Note: LifterLMS REST API doesn't have a direct login endpoint
      // You need to implement one of these approaches:
      // 1. Use WordPress JWT Authentication plugin
      // 2. Create custom authentication endpoint
      // 3. Use WordPress application passwords
      
      // For now, using a custom endpoint approach
      final response = await lmsService.api.login(
        username: username,
        password: password,
      );
      
      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');
      
      if (response.statusCode == 200) {
        // Parse login response
        final loginData = response.body;
        
        if (loginData != null && loginData['token'] != null) {
          // Save authentication data
          await saveAuthData(loginData);
          
          // Save credentials if remember me is checked
          if (rememberMe.value) {
            await prefs.setBool('remember_me', true);
            await prefs.setString('saved_username', username);
            await prefs.setString('saved_password', password);
          } else {
            await prefs.remove('remember_me');
            await prefs.remove('saved_username');
            await prefs.remove('saved_password');
          }
          
          // Get user details
          await getUserDetails(loginData['user_id'] ?? 0);
          
          // Register FCM token for notifications
          final notificationController = Get.find<NotificationController>();
          await notificationController.registerFCMToken(
            prefs.getString('fcm_token') ?? ''
          );
          
          // Refresh my courses if controller exists
          if (Get.isRegistered<MyCoursesController>()) {
            final myCoursesController = Get.find<MyCoursesController>();
            myCoursesController.refreshData();
          }
          
          DialogHelper.hideLoading();
          
          // Navigate to appropriate screen
          navigateAfterLogin();
        } else {
          throw Exception('Invalid login response');
        }
      } else if (response.statusCode == 401) {
        DialogHelper.hideLoading();
        showToast("Invalid username or password", isError: true);
      } else if (response.statusCode == 501) {
        // Authentication endpoint not implemented
        DialogHelper.hideLoading();
        showToast(
          "Authentication not configured. Please set up WordPress JWT Auth plugin.",
          isError: true
        );
      } else {
        DialogHelper.hideLoading();
        showToast(
          response.body?['message'] ?? "Login failed. Please try again.",
          isError: true
        );
      }
    } catch (e) {
      DialogHelper.hideLoading();
      showToast("An error occurred. Please try again.", isError: true);
      print('Login error: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Save authentication data
  Future<void> saveAuthData(Map<String, dynamic> loginData) async {
    // Save token
    final token = loginData['token'] ?? '';
    await prefs.setString('auth_token', token);
    
    // Extract user ID from JWT token
    int userId = 0;
    if (token.isNotEmpty) {
      try {
        Map<String, dynamic> payload = Jwt.parseJwt(token);
        print('JWT payload: $payload');
        
        // The user ID is in data.user.id
        if (payload.containsKey('data') && payload['data'] is Map) {
          final data = payload['data'] as Map;
          if (data.containsKey('user') && data['user'] is Map) {
            final user = data['user'] as Map;
            // Convert string ID to int
            userId = int.tryParse(user['id'].toString()) ?? 0;
            print('Extracted user ID from JWT: $userId');
          }
        }
      } catch (e) {
        print('Error decoding JWT token: $e');
      }
    }
    
    // If we still don't have a user ID, try the old field
    if (userId == 0) {
      userId = loginData['user_id'] ?? 0;
    }
    
    await prefs.setInt('user_id', userId);
    
    // Update LMS service
    await lmsService.setCurrentUser(userId, token);
    
    // Save user data
    userData.value = loginData;
  }
  
  /// Get user details
  Future<void> getUserDetails(int userId) async {
    if (userId == 0) return;
    
    try {
      final response = await lmsService.api.getStudent(studentId: userId);
      
      if (response.statusCode == 200) {
        final userInfo = response.body;
        
        // Save user information
        await prefs.setString('user_name', userInfo['name'] ?? '');
        await prefs.setString('user_email', userInfo['email'] ?? '');
        await prefs.setString('user_display_name', userInfo['display_name'] ?? '');
        await prefs.setString('user_avatar', userInfo['avatar_urls']?['96'] ?? '');
        
        // Update user data
        userData.value = {
          ...userData.value,
          if (userInfo is Map) ...userInfo,
        };
      }
    } catch (e) {
      print('Error getting user details: $e');
    }
  }
  
  /// Navigate after successful login
  void navigateAfterLogin() {
    // Check if there's a pending course to view
    final pendingCourseId = prefs.getString('pending_course_id');
    
    if (pendingCourseId != null && pendingCourseId.isNotEmpty) {
      // Clear pending course
      prefs.remove('pending_course_id');
      
      // Navigate to course detail
      Get.offAllNamed(
        AppRouter.getCourseDetail(),
        arguments: {'id': int.tryParse(pendingCourseId) ?? 0},
      );
    } else {
      // Navigate to home or tabs
      print('Navigating to route: ${AppRouter.getTabsBarRoute()}');
      try {
        Get.offAllNamed(AppRouter.getTabsBarRoute());
      } catch (e) {
        print('Navigation error: $e');
        // Fallback to tabs directly
        Get.offAllNamed('/tabs');
      }
    }
  }
  
  /// Logout user
  Future<void> logout() async {
    try {
      DialogHelper.showLoading();
      
      // Clear session in LMS service
      await lmsService.clearSession();
      
      // Clear saved data
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      await prefs.remove('user_display_name');
      await prefs.remove('user_avatar');
      
      // Clear user data
      userData.value = {};
      
      // Clear form if not remember me
      if (!rememberMe.value) {
        usernameController.clear();
        passwordController.clear();
      }
      
      DialogHelper.hideLoading();
      
      // Navigate to login
      Get.offAllNamed(AppRouter.login);
      
      showToast("Logged out successfully");
    } catch (e) {
      DialogHelper.hideLoading();
      showToast("Error logging out", isError: true);
      print('Logout error: $e');
    }
  }
  
  /// Navigate to forgot password
  void goToForgotPassword() {
    Get.toNamed(AppRouter.forgotPassword);
  }
  
  /// Navigate to register
  void goToRegister() {
    Get.toNamed(AppRouter.register);
  }
  
  /// Check if user is logged in
  bool get isLoggedIn => lmsService.isLoggedIn;
  
  /// Get current user ID
  int? get currentUserId => lmsService.currentUserId;
  
  // Input decoration for form fields
  final OutlineInputBorder enabledBorder = const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8.0)),
    borderSide: BorderSide(color: Colors.grey),
  );
  
  final OutlineInputBorder focusedBorder = const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8.0)),
    borderSide: BorderSide(color: Colors.blue, width: 2),
  );
  
  final OutlineInputBorder errorBorder = const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8.0)),
    borderSide: BorderSide(color: Colors.red),
  );
}