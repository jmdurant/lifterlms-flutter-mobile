import 'package:flutter_app/app/config/lms_config.dart';
import 'package:flutter_app/app/backend/api/api.dart';
import 'package:flutter_app/app/backend/services/lms_platform_service.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unified authentication service that handles both LearnPress and LifterLMS
class UnifiedAuthService extends GetxService {
  static UnifiedAuthService get to => Get.find();
  
  final ApiService apiService = Get.find<ApiService>();
  late SharedPreferences _prefs;
  
  // Observable states
  final RxBool _isLoggedIn = false.obs;
  final RxInt _userId = 0.obs;
  final RxString _userEmail = ''.obs;
  final RxString _userName = ''.obs;
  final RxString _authToken = ''.obs;
  
  
  bool get isLoggedIn => _isLoggedIn.value;
  int get userId => _userId.value;
  String get userEmail => _userEmail.value;
  String get userName => _userName.value;
  String get authToken => _authToken.value;
  
  @override
  void onInit() async {
    super.onInit();
    _prefs = await SharedPreferences.getInstance();
    await loadSession();
  }
  
  /// Load saved session
  Future<void> loadSession() async {
    _userId.value = _prefs.getInt('user_id') ?? 0;
    _userEmail.value = _prefs.getString('user_email') ?? '';
    _userName.value = _prefs.getString('user_name') ?? '';
    _authToken.value = _prefs.getString('auth_token') ?? '';
    
    _isLoggedIn.value = _userId.value > 0 || _authToken.value.isNotEmpty;
    
    // Update platform service
    if (_isLoggedIn.value && Get.isRegistered<LMSPlatformService>()) {
      final platformService = Get.find<LMSPlatformService>();
      await platformService.setCurrentUser(_userId.value, _authToken.value);
    }
  }
  
  /// Save session
  Future<void> saveSession() async {
    await _prefs.setInt('user_id', _userId.value);
    await _prefs.setString('user_email', _userEmail.value);
    await _prefs.setString('user_name', _userName.value);
    await _prefs.setString('auth_token', _authToken.value);
  }
  
  /// Clear session
  Future<void> clearSession() async {
    _userId.value = 0;
    _userEmail.value = '';
    _userName.value = '';
    _authToken.value = '';
    _isLoggedIn.value = false;
    
    await _prefs.remove('user_id');
    await _prefs.remove('user_email');
    await _prefs.remove('user_name');
    await _prefs.remove('auth_token');
    
    // Clear platform service session
    if (Get.isRegistered<LMSPlatformService>()) {
      final platformService = Get.find<LMSPlatformService>();
      await platformService.clearSession();
    }
  }
  
  /// Universal login method
  Future<Response> login({
    required String username,
    required String password,
  }) async {
    try {
      Response response;
      
      if (LMSConfig.isLearnPress) {
        // LearnPress login
        response = await _loginLearnPress(username, password);
      } else {
        // LifterLMS login
        response = await _loginLifterLMS(username, password);
      }
      
      if (response.statusCode == 200) {
        _isLoggedIn.value = true;
        await saveSession();
        
        // Update platform service
        if (Get.isRegistered<LMSPlatformService>()) {
          final platformService = Get.find<LMSPlatformService>();
          await platformService.setCurrentUser(_userId.value, _authToken.value);
        }
      }
      
      return response;
    } catch (e) {
      return Response(
        statusCode: 500,
        statusText: 'Login failed: $e',
      );
    }
  }
  
  /// LearnPress login
  Future<Response> _loginLearnPress(String username, String password) async {
    final response = await apiService.postPublic(
      'wp-json/learnpress/v1/token',
      {
        'username': username,
        'password': password,
      },
    );
    
    if (response.statusCode == 200 && response.body != null) {
      final data = response.body;
      
      // Save user info
      _authToken.value = data['token'] ?? '';
      _userId.value = data['user']?['id'] ?? 0;
      _userEmail.value = data['user']?['email'] ?? '';
      _userName.value = data['user']?['display_name'] ?? username;
      
      return Response(
        statusCode: 200,
        body: {
          'success': true,
          'message': 'Login successful',
          'user': data['user'],
          'token': _authToken.value,
        },
      );
    }
    
    return response;
  }
  
  /// LifterLMS login using JWT
  Future<Response> _loginLifterLMS(String username, String password) async {
    // LifterLMS requires JWT Authentication plugin
    final response = await apiService.postPublic(
      'wp-json/jwt-auth/v1/token',
      {
        'username': username,
        'password': password,
      },
    );
    
    if (response.statusCode == 200 && response.body != null) {
      final data = response.body;
      
      // Save user info (JWT response format)
      _authToken.value = data['token'] ?? '';
      _userId.value = data['data']?['ID'] ?? 0;
      _userEmail.value = data['user_email'] ?? '';
      _userName.value = data['user_display_name'] ?? username;
      
      return Response(
        statusCode: 200,
        body: {
          'success': true,
          'message': 'Login successful',
          'token': _authToken.value,
        },
      );
    }
    
    // If JWT plugin not installed, provide clear error
    if (response.statusCode == 404) {
      return Response(
        statusCode: 404,
        body: {
          'success': false,
          'message': 'JWT Authentication plugin not installed',
          'instructions': 'Please install and configure the JWT Authentication for WP REST API plugin on your LifterLMS site.',
        },
      );
    }
    
    return response;
  }
  
  /// Register new user
  Future<Response> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
      Response response;
      
      if (LMSConfig.isLearnPress) {
        // LearnPress registration
        response = await apiService.postPublic(
          'wp-json/learnpress/v1/token/register',
          {
            'username': username,
            'email': email,
            'password': password,
            if (firstName != null) 'first_name': firstName,
            if (lastName != null) 'last_name': lastName,
          },
        );
      } else {
        // LifterLMS registration
        final lmsService = Get.find<LMSPlatformService>();
        response = await lmsService.api.register(
          userData: {
            'username': username,
            'email': email,
            'password': password,
            if (firstName != null) 'first_name': firstName,
            if (lastName != null) 'last_name': lastName,
          },
        );
      }
      
      return response;
    } catch (e) {
      return Response(
        statusCode: 500,
        statusText: 'Registration failed: $e',
      );
    }
  }
  
  /// Logout
  Future<void> logout() async {
    await clearSession();
    
    // Navigate to login
    Get.offAllNamed('/login');
  }
  
  /// Get authentication headers for API requests
  Map<String, String> getAuthHeaders() {
    // Both platforms use JWT Bearer tokens
    if (_authToken.value.isNotEmpty) {
      return {
        'Authorization': 'Bearer ${_authToken.value}',
      };
    }
    return {};
  }
  
  /// Get authentication setup instructions
  String get authSetupInstructions {
    if (LMSConfig.isLifterLMS) {
      return '''
LifterLMS requires the JWT Authentication plugin:

1. Install "JWT Authentication for WP REST API" plugin
2. Add to wp-config.php:
   define('JWT_AUTH_SECRET_KEY', 'your-secret-key');
   define('JWT_AUTH_CORS_ENABLE', true);
3. Activate the plugin
4. Login with your WordPress username and password
      ''';
    }
    return '';
  }
}