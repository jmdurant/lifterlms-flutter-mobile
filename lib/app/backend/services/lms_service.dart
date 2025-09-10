import 'package:flutter_app/app/backend/api/lms_api_interface.dart';
import 'package:flutter_app/app/backend/api/lifterlms_api.dart';
import 'package:flutter_app/app/backend/api/api.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_section_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_lesson_model.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central LMS Service that manages API implementation
class LMSService extends GetxService {
  static LMSService get to => Get.find();
  
  late LMSApiInterface _api;
  late SharedPreferences _prefs;
  // Repositories
  CourseRepository? _courses;
  
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

/// Lightweight repository for course structure with simple in-memory caches
class CourseRepository {
  final LMSService _lms;
  final Duration ttl;

  CourseRepository(this._lms, {this.ttl = const Duration(minutes: 10)});

  final Map<int, LLMSCourseModel> _courseCache = {};
  final Map<int, DateTime> _courseTs = {};

  final Map<int, List<LLMSSectionModel>> _sectionsCache = {};
  final Map<int, DateTime> _sectionsTs = {};

  final Map<int, List<LLMSLessonModel>> _sectionLessonsCache = {};
  final Map<int, DateTime> _sectionLessonsTs = {};

  bool _fresh(DateTime? ts) => ts != null && DateTime.now().difference(ts) < ttl;

  Future<LLMSCourseModel?> getCourse(int courseId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _courseCache.containsKey(courseId) && _fresh(_courseTs[courseId])) {
      return _courseCache[courseId];
    }
    final res = await _lms.api.getCourse(courseId: courseId);
    if (res.statusCode == 200) {
      final model = LLMSCourseModel.fromJson(res.body);
      _courseCache[courseId] = model;
      _courseTs[courseId] = DateTime.now();
      return model;
    }
    return null;
  }

  Future<List<LLMSSectionModel>> getSections(int courseId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _sectionsCache.containsKey(courseId) && _fresh(_sectionsTs[courseId])) {
      return _sectionsCache[courseId]!;
    }
    final res = await _lms.api.getSections(courseId: courseId);
    if (res.statusCode == 200 && res.body is List) {
      final sections = <LLMSSectionModel>[];
      for (final s in res.body) {
        try {
          // Build section with empty lessons list; lessons are fetched on demand
          final section = LLMSSectionModel.fromJson(s);
          sections.add(LLMSSectionModel(
            id: section.id,
            title: section.title,
            courseId: section.courseId,
            order: section.order,
            parentId: section.parentId,
            permalink: section.permalink,
            postType: section.postType,
            lessons: <LLMSLessonModel>[],
          ));
        } catch (_) {}
      }
      _sectionsCache[courseId] = sections;
      _sectionsTs[courseId] = DateTime.now();
      return sections;
    }
    return _sectionsCache[courseId] ?? <LLMSSectionModel>[];
  }

  Future<List<LLMSLessonModel>> getSectionLessons(int sectionId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _sectionLessonsCache.containsKey(sectionId) && _fresh(_sectionLessonsTs[sectionId])) {
      return _sectionLessonsCache[sectionId]!;
    }
    // Use concrete API service for section content helper
    final api = _lms.api as LifterLMSApiService;
    final res = await api.getSectionContent(sectionId: sectionId);
    if (res.statusCode == 200 && res.body is List) {
      final lessons = <LLMSLessonModel>[];
      for (final l in res.body) {
        try {
          lessons.add(LLMSLessonModel.fromJson(l));
        } catch (_) {}
      }
      _sectionLessonsCache[sectionId] = lessons;
      _sectionLessonsTs[sectionId] = DateTime.now();
      return lessons;
    }
    return _sectionLessonsCache[sectionId] ?? <LLMSLessonModel>[];
  }

  void invalidateCourse(int courseId) {
    _courseTs.remove(courseId);
    _sectionsTs.remove(courseId);
  }

  void invalidateSection(int sectionId) {
    _sectionLessonsTs.remove(sectionId);
  }
}

extension LMSServiceRepositories on LMSService {
  CourseRepository get courses => _courses ??= CourseRepository(this);

  // Plugin endpoint wrappers (certificates, devices)
  ApiService get _apiService => Get.find<ApiService>();

  Future<Response> getCertificates({int page = 1, int perPage = 20}) async {
    // Call the LifterLMS API directly with Basic Auth
    return api.getCertificates(page: page, limit: perPage);
  }

  Future<Response> getCertificateDownloadData(int certificateId) async {
    // Use Basic Auth like other certificate methods
    return api.getCertificateDownload(certificateId);
  }

  Future<Response> shareCertificateLink(int certificateId, {String method = 'link'}) async {
    final token = _currentUserToken ?? '';
    return _apiService.postPrivate(
      'wp-json/llms/v1/mobile-app/certificate/$certificateId/share',
      {'method': method},
      token,
    );
  }

  Future<Response> verifyCertificate({required int certificateId, String? code}) async {
    final token = _currentUserToken ?? '';
    final body = <String, dynamic>{'certificate_id': certificateId};
    if (code != null) body['verification_code'] = code;
    return _apiService.postPrivate(
      'wp-json/llms/v1/mobile-app/certificate/verify',
      body,
      token,
    );
  }

  Future<Response> getCourseCertificates(int courseId) async {
    final token = _currentUserToken ?? '';
    return _apiService.getPrivate(
      'wp-json/llms/v1/mobile-app/course/$courseId/certificates',
      token,
      null,
    );
  }

  Future<Response> registerDevice(String fcmToken) async {
    if (_currentUserId == null) return const Response(statusCode: 401, statusText: 'Not logged in');
    return _api.registerDeviceToken(token: fcmToken, userId: _currentUserId!);
  }

  Future<Response> unregisterDevice(String fcmToken) async {
    return _api.unregisterDeviceToken(token: fcmToken);
  }
}
