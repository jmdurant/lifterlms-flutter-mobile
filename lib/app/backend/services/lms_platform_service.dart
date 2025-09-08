import 'package:flutter_app/app/backend/api/lifterlms_api.dart';
import 'package:flutter_app/app/backend/api/api.dart';
import 'package:flutter_app/app/config/lms_config.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enhanced LMS Service that supports both LearnPress and LifterLMS
class LMSPlatformService extends GetxService {
  static LMSPlatformService get to => Get.find();
  
  late LifterLMSApiService api;
  late SharedPreferences _prefs;
  
  // Observable states
  final RxBool _isInitialized = false.obs;
  final RxString _currentPlatform = LMSConfig.platform.obs;
  
  // Configuration
  String _baseUrl = '';
  String? _consumerKey;
  String? _consumerSecret;
  
  // User session
  int? _currentUserId;
  String? _authToken;
  
  bool get isInitialized => _isInitialized.value;
  String get currentPlatform => _currentPlatform.value;
  int? get currentUserId => _currentUserId;
  bool get isLoggedIn => _currentUserId != null || _authToken != null;
  
  /// Initialize the service
  Future<LMSPlatformService> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadConfiguration();
    _initializeApi();
    await _loadUserSession();
    return this;
  }
  
  /// Load configuration from shared preferences or config file
  Future<void> _loadConfiguration() async {
    // Load platform preference
    final savedPlatform = _prefs.getString('lms_platform');
    if (savedPlatform != null) {
      LMSConfig.switchPlatform(savedPlatform);
      _currentPlatform.value = savedPlatform;
    }
    
    final config = LMSConfig.getConfig();
    
    if (LMSConfig.isLearnPress) {
      _baseUrl = _prefs.getString('learnpress_base_url') ?? config['baseUrl'];
    } else {
      _baseUrl = _prefs.getString('lifterlms_base_url') ?? config['baseUrl'];
      _consumerKey = _prefs.getString('lifterlms_consumer_key') ?? config['consumerKey'];
      _consumerSecret = _prefs.getString('lifterlms_consumer_secret') ?? config['consumerSecret'];
    }
  }
  
  /// Initialize the appropriate API based on platform
  void _initializeApi() {
    // Initialize LifterLMS API only
    api = LifterLMSApiService(
      appBaseUrl: _baseUrl,
      consumerKey: _consumerKey ?? '',
      consumerSecret: _consumerSecret ?? '',
    );
    
    _isInitialized.value = true;
  }
  
  /// Load user session from storage
  Future<void> _loadUserSession() async {
    _currentUserId = _prefs.getInt('current_user_id');
    _authToken = _prefs.getString('auth_token');
    
    // LifterLMS uses consumer key/secret, not auth tokens
  }
  
  /// Switch to a different LMS platform
  Future<void> switchPlatform(String platform) async {
    if (platform != 'learnpress' && platform != 'lifterlms') {
      throw ArgumentError('Invalid platform: $platform');
    }
    
    // Clear current session
    await clearSession();
    
    // Switch platform
    LMSConfig.switchPlatform(platform);
    _currentPlatform.value = platform;
    
    // Save preference
    await _prefs.setString('lms_platform', platform);
    
    // Reinitialize
    await _loadConfiguration();
    _initializeApi();
  }
  
  /// Update configuration for LearnPress
  Future<void> updateLearnPressConfig({
    required String baseUrl,
  }) async {
    _baseUrl = baseUrl;
    await _prefs.setString('learnpress_base_url', baseUrl);
    
    if (LMSConfig.isLearnPress) {
      _initializeApi();
    }
  }
  
  /// Update configuration for LifterLMS
  Future<void> updateLifterLMSConfig({
    required String baseUrl,
    required String consumerKey,
    required String consumerSecret,
  }) async {
    _baseUrl = baseUrl;
    _consumerKey = consumerKey;
    _consumerSecret = consumerSecret;
    
    await _prefs.setString('lifterlms_base_url', baseUrl);
    await _prefs.setString('lifterlms_consumer_key', consumerKey);
    await _prefs.setString('lifterlms_consumer_secret', consumerSecret);
    
    if (LMSConfig.isLifterLMS) {
      _initializeApi();
    }
  }
  
  /// Set current user session
  Future<void> setCurrentUser(int userId, String? token) async {
    _currentUserId = userId;
    _authToken = token;
    
    await _prefs.setInt('current_user_id', userId);
    if (token != null) {
      await _prefs.setString('auth_token', token);
      // LifterLMS uses consumer key/secret, not auth tokens
    }
  }
  
  /// Clear user session
  Future<void> clearSession() async {
    _currentUserId = null;
    _authToken = null;
    
    await _prefs.remove('current_user_id');
    await _prefs.remove('auth_token');
  }
  
  /// Logout
  Future<void> logout() async {
    await clearSession();
  }
  
  // ===== Convenience methods that use current user =====
  
  Future<Response> getMyEnrollments({Map<String, String>? params}) async {
    if (_currentUserId == null) {
      return Response(statusCode: 401, statusText: 'Not logged in');
    }
    return api.getStudentEnrollments(studentId: _currentUserId!);
  }
  
  Future<Response> enrollInCourse(int courseId) async {
    if (_currentUserId == null) {
      return Response(statusCode: 401, statusText: 'Not logged in');
    }
    return api.enrollInCourse(userId: _currentUserId!, courseId: courseId);
  }
  
  Future<Response> getCourseProgress(int courseId) async {
    if (_currentUserId == null) {
      return Response(statusCode: 401, statusText: 'Not logged in');
    }
    return api.getCourseProgress(userId: _currentUserId!, courseId: courseId);
  }
  
  Future<Response> completeLesson(int lessonId) async {
    if (_currentUserId == null) {
      return Response(statusCode: 401, statusText: 'Not logged in');
    }
    return api.completeLesson(userId: _currentUserId!, lessonId: lessonId);
  }
  
  Future<Response> getWishlist() async {
    if (_currentUserId == null) {
      return Response(statusCode: 401, statusText: 'Not logged in');
    }
    return api.getWishlist(userId: _currentUserId!);
  }
  
  Future<Response> addToWishlist(int courseId) async {
    if (_currentUserId == null) {
      return Response(statusCode: 401, statusText: 'Not logged in');
    }
    return api.addToWishlist(userId: _currentUserId!, courseId: courseId);
  }
  
  Future<Response> removeFromWishlist(int courseId) async {
    if (_currentUserId == null) {
      return Response(statusCode: 401, statusText: 'Not logged in');
    }
    return api.removeFromWishlist(userId: _currentUserId!, courseId: courseId);
  }
}