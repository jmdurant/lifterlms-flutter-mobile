import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/api/lms_api_interface.dart';
import 'package:flutter_app/app/backend/api/lifterlms_api_stubs.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class LifterLMSApiService extends GetxService with LifterLMSApiStubs implements LMSApiInterface {
  final String appBaseUrl;
  final String consumerKey;
  final String consumerSecret;
  static const String connectionIssue = 'Connection failed!';
  final int timeoutInSeconds = 30;

  LifterLMSApiService({
    required this.appBaseUrl,
    required this.consumerKey,
    required this.consumerSecret,
  });

  // Generate Basic Auth header
  String _getAuthHeader() {
    final credentials = '$consumerKey:$consumerSecret';
    final encoded = base64Encode(utf8.encode(credentials));
    return 'Basic $encoded';
  }

  
  // Get combined headers for authenticated requests
  Map<String, String> _getAuthenticatedHeaders() {
    final headers = <String, String>{
      'Authorization': _getAuthHeader(),
      'Content-Type': 'application/json',
    };
    
    // Add JWT token as a separate header if available
    if (Get.isRegistered<LMSService>()) {
      final lmsService = Get.find<LMSService>();
      final token = lmsService.currentUserToken;
      if (token != null && token.isNotEmpty) {
        // Add JWT token as custom header for user context
        headers['X-JWT-Token'] = token;
      }
    }
    
    return headers;
  }

  // Alternative: Use header-based auth
  Map<String, String> _getAuthHeaders() {
    return {
      'X-LLMS-Consumer-Key': consumerKey,
      'X-LLMS-Consumer-Secret': consumerSecret,
      'Content-Type': 'application/json',
    };
  }
  
  // GET Course Categories (WordPress taxonomy)
  Future<Response> getCategories({Map<String, dynamic>? params}) async {
    final queryParams = params ?? {};
    final queryString = Uri(queryParameters: queryParams.map((key, value) => MapEntry(key, value.toString()))).query;
    final url = Uri.parse('$appBaseUrl/wp-json/wp/v2/course_cat${queryString.isNotEmpty ? '?$queryString' : ''}');
    
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }

  // GET WordPress Media
  Future<Response> getMedia({required int mediaId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/wp/v2/media/$mediaId');
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  // GET Featured Image using WordPress oEmbed (no auth required, much faster!)
  @override
  Future<Response> getOEmbedData({required String courseUrl}) async {
    final encodedUrl = Uri.encodeComponent(courseUrl);
    final url = Uri.parse('$appBaseUrl/wp-json/oembed/1.0/embed?url=$encodedUrl');
    
    try {
      final response = await http.get(url).timeout(Duration(seconds: timeoutInSeconds));
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }

  // GET Courses
  Future<Response> getCourses({Map<String, dynamic>? params}) async {
    final queryString = params != null ? "?${Uri(queryParameters: params).query}" : "";
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/courses$queryString');
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }

  // GET Single Course - removed duplicate, see getCourse override implementation below

  // GET Lessons
  Future<Response> getLessons({Map<String, dynamic>? params}) async {
    final queryString = params != null ? "?${Uri(queryParameters: params).query}" : "";
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/lessons$queryString');
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }

  // GET Single Lesson
  @override
  Future<Response> getLesson({required int lessonId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/lessons/$lessonId');
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }

  // GET Sections
  @override
  Future<Response> getSections({required int courseId}) async {
    // LifterLMS uses parent parameter to filter sections by course
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/sections?parent=$courseId');
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  // GET Section Content (Lessons)
  Future<Response> getSectionContent({required int sectionId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/sections/$sectionId/content');
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      print('Error getting section content: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }

  // GET Students
  Future<Response> getStudents({Map<String, dynamic>? params}) async {
    final queryString = params != null ? "?${Uri(queryParameters: params).query}" : "";
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/students$queryString');
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }

  // GET Student by ID
  Future<Response> getStudent({int? studentId}) async {
    if (studentId == null) {
      // Get current user
      return getCurrentUser();
    }
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/students/$studentId');
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }

  // GET Student Enrollments
  Future<Response> getStudentEnrollments({required int studentId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/students/$studentId/enrollments');
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }

  // POST Enrollment
  Future<Response> enrollStudent(int studentId, int courseId) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/students/$studentId/enrollments/$courseId');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': 'enrolled',
        }),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }

  // DELETE Enrollment (Unenroll)
  Future<Response> unenrollStudent(int studentId, int courseId) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/students/$studentId/enrollments/$courseId');
    
    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }

  // GET Student Progress
  Future<Response> getStudentProgress(int studentId, int postId) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/students/$studentId/progress/$postId');
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }

  // UPDATE Student Progress
  Future<Response> updateStudentProgress(int studentId, int postId, String status) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/students/$studentId/progress/$postId');
    
    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': status, // 'complete' or 'incomplete'
        }),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }

  // GET Instructors
  Future<Response> getInstructors({Map<String, dynamic>? params}) async {
    final queryString = params != null ? "?${Uri(queryParameters: params).query}" : "";
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/instructors$queryString');
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  // GET WordPress Users  
  Future<Response> getUsers({Map<String, dynamic>? params}) async {
    final queryString = params != null ? "?${Uri(queryParameters: params).query}" : "";
    final url = Uri.parse('$appBaseUrl/wp-json/wp/v2/users$queryString');
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }

  // GET Memberships
  Future<Response> getMemberships({Map<String, dynamic>? params}) async {
    final queryString = params != null ? "?${Uri(queryParameters: params).query}" : "";
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/memberships$queryString');
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }

  // Authentication Methods
  @override
  Future<Response> login({required String username, required String password}) async {
    // LifterLMS doesn't have a direct login endpoint via REST
    // This would need to be implemented as a custom endpoint
    // For now, we'll use WordPress authentication
    final url = Uri.parse('$appBaseUrl/wp-json/jwt-auth/v1/token');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> register({required Map<String, dynamic> userData}) async {
    // Custom endpoint needed
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/students');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(userData),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> forgotPassword({required String email}) async {
    // Custom endpoint needed
    return const Response(statusCode: 501, statusText: 'Not implemented');
  }
  
  @override
  Future<Response> changePassword({required String oldPassword, required String newPassword}) async {
    // Custom endpoint needed
    return const Response(statusCode: 501, statusText: 'Not implemented');
  }
  
  // User Management
  @override
  Future<Response> getCurrentUser() async {
    final url = Uri.parse('$appBaseUrl/wp-json/wp/v2/users/me');
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> updateUser({required int userId, required Map<String, dynamic> userData}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/students/$userId');
    
    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(userData),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> deleteUser({required int userId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/students/$userId');
    
    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  // Courses Implementation
  @override
  Future<Response> getCourse({required int courseId}) async {
    return getCourseById(courseId);
  }
  
  Future<Response> getCourseById(int courseId) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/courses/$courseId');
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> getPopularCourses({int page = 1, int perPage = 10}) async {
    // LifterLMS doesn't have a built-in popular courses endpoint
    // This would need custom implementation or use regular courses with sorting
    return getCourses(params: {
      'page': page.toString(),
      'per_page': perPage.toString(),
      'orderby': 'enrollment_count', // Custom meta field needed
      'order': 'desc',
    });
  }
  
  @override
  Future<Response> getNewCourses({int page = 1, int perPage = 10}) async {
    return getCourses(params: {
      'page': page.toString(),
      'per_page': perPage.toString(),
      'orderby': 'date',
      'order': 'desc',
    });
  }
  
  @override
  Future<Response> searchCourses({required String query, Map<String, dynamic>? params}) async {
    final searchParams = {
      'search': query,
      ...?params,
    };
    return getCourses(params: searchParams);
  }
  
  // Enrollment Management
  @override
  Future<Response> enrollInCourse({required int userId, required int courseId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/students/$userId/enrollments/$courseId');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$consumerKey:$consumerSecret'))}',
        },
        body: jsonEncode({
          'trigger': 'admin_enrollment',  // Use a meaningful trigger
        }),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      print('Enrollment response status: ${response.statusCode}');
      print('Enrollment response body: ${response.body}');
      
      return parseResponse(response, url.toString());
    } catch (e) {
      print('Error enrolling in course: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> unenrollFromCourse({required int userId, required int courseId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/students/$userId/enrollments/$courseId');
    
    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$consumerKey:$consumerSecret'))}',
        },
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      print('Error unenrolling from course: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> getEnrollmentStatus({required int userId, required int courseId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/students/$userId/enrollments/$courseId');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$consumerKey:$consumerSecret'))}',
        },
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      print('Error checking enrollment status: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> getMyEnrollments({required int userId, Map<String, dynamic>? params}) async {
    final queryParams = params != null ? '?${Uri(queryParameters: params).query}' : '';
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/students/$userId/enrollments$queryParams');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$consumerKey:$consumerSecret'))}',
        },
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      print('Error getting enrollments: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  // Parse Response
  Response parseResponse(http.Response res, String uri) {
    dynamic body;
    try {
      body = jsonDecode(res.body);
    } catch (e) {
      print('Error parsing response: $e');
    }

    Response response = Response(
      body: body ?? res.body,
      bodyString: res.body.toString(),
      headers: res.headers,
      statusCode: res.statusCode,
      statusText: res.reasonPhrase,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      if (response.body != null && response.body is Map) {
        final errorMessage = response.body['message'] ?? 'Unknown error';
        response = Response(
          statusCode: response.statusCode,
          body: response.body,
          statusText: errorMessage,
        );
      }
      
      // Handle authentication errors globally
      if (response.statusCode == 401 || response.statusCode == 403) {
        print('Auth error from URL: $uri');
        print('Response status: ${response.statusCode}, body: ${response.body}');
        _handleAuthError(response.statusCode ?? 0, response.body, uri);
      }
    }

    return response;
  }
  
  // Handle authentication errors
  void _handleAuthError(int statusCode, dynamic body, String url) {
    if (statusCode == 401) {
      // Skip auth error handling for media endpoints - these often fail due to privacy settings
      if (url.contains('/wp-json/wp/v2/media/')) {
        print('Media access denied (private media): $url');
        return;
      }
      
      // Token expired or invalid credentials
      print('Authentication failed: Token expired or invalid');
      
      // Clear stored credentials
      if (Get.isRegistered<LMSService>()) {
        final lmsService = Get.find<LMSService>();
        lmsService.clearSession();
      }
      
      // Redirect to login if not already there
      if (Get.currentRoute != '/login' && Get.currentRoute != '/splash') {
        Get.offAllNamed('/login');
        Get.snackbar(
          'Session Expired',
          'Please log in again to continue',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.9),
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }
    } else if (statusCode == 403) {
      // Forbidden - user doesn't have permission
      print('Access forbidden: User lacks permission');
      Get.snackbar(
        'Access Denied',
        body?['message'] ?? 'You do not have permission to access this resource',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.withOpacity(0.9),
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    }
  }
  
  // ===== Override stub implementations with actual API calls =====
  
  // Social Login Methods (use our WordPress plugin)
  @override
  Future<Response> loginWithGoogle({required String token}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/mobile-app/verify-google');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> loginWithFacebook({required String token}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/mobile-app/verify-facebook');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> loginWithApple({required String token}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/mobile-app/verify-apple');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identityToken': token}),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  // Push Notification Methods (use our WordPress plugin)
  @override
  Future<Response> getNotifications({required int userId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/mobile-app/notifications');
    final queryParams = {'user_id': userId.toString()};
    final uri = Uri.parse(url.toString()).replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, uri.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> markNotificationRead({required int notificationId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/mobile-app/notifications/mark-read');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'notification_id': notificationId}),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> registerDeviceToken({required String token, required int userId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/mobile-app/register-device');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'device_token': token,
          'user_id': userId,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> unregisterDeviceToken({required String token}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/mobile-app/unregister-device');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'device_token': token}),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> getCourseProgress({required int userId, required int courseId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/students/$userId/progress/$courseId');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      print('Error getting course progress: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  // In-App Purchase Methods (use our WordPress plugin)
  @override
  Future<Response> getProducts() async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/mobile-app/product-iap');
    
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> verifyPurchase({required String receipt, required String productId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/mobile-app/verify-receipt');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'receipt': receipt,
          'product_id': productId,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
}