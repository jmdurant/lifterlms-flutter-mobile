import 'package:flutter_app/app/backend/api/lms_api_interface.dart';
import 'package:flutter_app/app/backend/api/lifterlms_api.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central LMS Service that manages API implementation
class LMSService extends GetxService {
  static LMSService get to => Get.find();
  
  late LMSApiInterface _api;
  late SharedPreferences _prefs;
  
  // Configuration
  String _baseUrl = '';
  String _consumerKey = '';
  String _consumerSecret = '';
  
  // User session
  int? _currentUserId;
  String? _currentUserToken;
  
  LMSApiInterface get api => _api;
  int? get currentUserId => _currentUserId;
  String? get currentUserToken => _currentUserToken;
  bool get isLoggedIn => _currentUserId != null;
  
  /// Get current user (for compatibility)
  Map<String, dynamic>? get currentUser => _currentUserId != null 
    ? {'id': _currentUserId} 
    : null;
  
  Future<LMSService> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadConfiguration();
    _initializeApi();
    await _loadUserSession();
    return this;
  }
  
  Future<void> _loadConfiguration() async {
    // Use test site credentials
    _baseUrl = _prefs.getString('lms_base_url') ?? 'https://polite-tree.myliftersite.com';
    _consumerKey = _prefs.getString('lms_consumer_key') ?? 'ck_0f0e0588e103e6ef372015eaa36a6c8ee1cddd59';
    _consumerSecret = _prefs.getString('lms_consumer_secret') ?? 'cs_08f3bc87adcb6a090a2620479d91031d75ec213a';
  }
  
  Future<void> _loadUserSession() async {
    _currentUserId = _prefs.getInt('current_user_id');
    _currentUserToken = _prefs.getString('current_user_token');
    
    // Validate session on startup
    if (_currentUserId != null) {
      await validateSession();
    }
  }
  
  /// Validate current session by checking if user can still access their profile
  Future<bool> validateSession() async {
    if (_currentUserId == null) return false;
    
    try {
      print('Validating session for user ID: $_currentUserId');
      final response = await _api.getStudent(studentId: _currentUserId);
      
      print('Session validation response: ${response.statusCode}, body: ${response.body}');
      
      if (response.statusCode == 200) {
        print('Session validated successfully');
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print('Session invalid (${response.statusCode}), clearing credentials');
        // Don't clear session automatically - let user re-login manually
        // await clearSession();
        return false;
      }
    } catch (e) {
      print('Error validating session: $e');
    }
    
    return false;
  }
  
  void _initializeApi() {
    _api = LifterLMSApiService(
      appBaseUrl: _baseUrl,
      consumerKey: _consumerKey,
      consumerSecret: _consumerSecret,
    );
  }
  
  Future<void> updateConfiguration({
    required String baseUrl,
    required String consumerKey,
    required String consumerSecret,
  }) async {
    _baseUrl = baseUrl;
    _consumerKey = consumerKey;
    _consumerSecret = consumerSecret;
    
    await _prefs.setString('lms_base_url', baseUrl);
    await _prefs.setString('lms_consumer_key', consumerKey);
    await _prefs.setString('lms_consumer_secret', consumerSecret);
    
    _initializeApi();
  }
  
  Future<void> setCurrentUser(int userId, String? token) async {
    _currentUserId = userId;
    _currentUserToken = token;
    
    await _prefs.setInt('current_user_id', userId);
    if (token != null) {
      await _prefs.setString('current_user_token', token);
    }
  }
  
  Future<void> clearSession() async {
    _currentUserId = null;
    _currentUserToken = null;
    
    await _prefs.remove('current_user_id');
    await _prefs.remove('current_user_token');
  }
  
  Future<void> logout() async {
    await clearSession();
  }
  
  // Convenience methods that automatically use current user
  Future<Response> getMyEnrollments({Map<String, dynamic>? params}) async {
    if (_currentUserId == null) {
      return const Response(statusCode: 401, statusText: 'Not logged in');
    }
    return _api.getMyEnrollments(userId: _currentUserId!, params: params);
  }
  
  Future<Response> enrollInCourse(int courseId) async {
    if (_currentUserId == null) {
      return const Response(statusCode: 401, statusText: 'Not logged in');
    }
    return _api.enrollInCourse(userId: _currentUserId!, courseId: courseId);
  }
  
  Future<Response> getCourseProgress(int courseId) async {
    if (_currentUserId == null) {
      return const Response(statusCode: 401, statusText: 'Not logged in');
    }
    return _api.getCourseProgress(userId: _currentUserId!, courseId: courseId);
  }
  
  Future<Response> completeLesson(int lessonId) async {
    if (_currentUserId == null) {
      return const Response(statusCode: 401, statusText: 'Not logged in');
    }
    return _api.completeLesson(lessonId: lessonId, userId: _currentUserId!);
  }
  
  Future<Response> getWishlist() async {
    if (_currentUserId == null) {
      return const Response(statusCode: 401, statusText: 'Not logged in');
    }
    return _api.getWishlist(userId: _currentUserId!);
  }
  
  Future<Response> addToWishlist(int courseId) async {
    if (_currentUserId == null) {
      return const Response(statusCode: 401, statusText: 'Not logged in');
    }
    return _api.addToWishlist(userId: _currentUserId!, courseId: courseId);
  }
  
  Future<Response> removeFromWishlist(int courseId) async {
    if (_currentUserId == null) {
      return const Response(statusCode: 401, statusText: 'Not logged in');
    }
    return _api.removeFromWishlist(userId: _currentUserId!, courseId: courseId);
  }
}