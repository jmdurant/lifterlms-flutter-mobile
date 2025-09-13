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
  @override
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
  @override
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
  @override
  Future<Response> getCourses({Map<String, dynamic>? params}) async {
    // Note: LifterLMS API doesn't support author filtering, so we'll do it client-side
    // Remove author param from API call but keep it for later filtering
    final authorId = params?.remove('author');
    
    final queryString = params != null ? "?${Uri(queryParameters: params).query}" : "";
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/courses$queryString');
    
    // Debug logging
    print('LifterLMSApiService.getCourses - Request URL: $url');
    if (authorId != null) {
      print('LifterLMSApiService.getCourses - Will filter by author $authorId client-side');
    }
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      }).timeout(Duration(seconds: timeoutInSeconds));
      
      // Put the author param back for client-side filtering
      if (authorId != null && params != null) {
        params['author'] = authorId;
      }
      
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
  @override
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
  @override
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

  // UPDATE Student Progress - Note: Uses POST method, not PATCH!
  Future<Response> updateStudentProgress(int studentId, int postId, String status) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/students/$studentId/progress/$postId');
    
    print('LifterlmsAPI.updateStudentProgress - URL: $url');
    print('LifterlmsAPI.updateStudentProgress - Method: POST (not PATCH!)');
    print('LifterlmsAPI.updateStudentProgress - Status: $status');
    
    try {
      final response = await http.post(  // Changed from PATCH to POST!
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
      print('LifterlmsAPI.updateStudentProgress - ERROR: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  // Complete a lesson
  Future<Response> completeLesson({required int lessonId, required int userId}) async {
    print('LifterlmsAPI.completeLesson - Marking lesson $lessonId complete for user $userId');
    // Use the updateStudentProgress method with 'complete' status
    return updateStudentProgress(userId, lessonId, 'complete');
  }
  
  // Get quiz details
  Future<Response> getQuiz({required int quizId}) async {
    print('LifterlmsAPI.getQuiz - Getting quiz ID: $quizId');
    
    try {
      final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/mobile-app/quiz/$quizId');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
      );
      
      print('LifterlmsAPI.getQuiz - Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return Response(
          statusCode: response.statusCode,
          statusText: response.reasonPhrase,
          body: jsonDecode(response.body),
        );
      } else {
        print('LifterlmsAPI.getQuiz - Error response: ${response.body}');
        return Response(
          statusCode: response.statusCode,
          statusText: response.reasonPhrase,
          body: response.body.isNotEmpty ? jsonDecode(response.body) : null,
        );
      }
    } catch (e) {
      print('LifterlmsAPI.getQuiz - Error: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  // Start quiz attempt
  Future<Response> startQuizAttempt({
    required int quizId,
    required int lessonId,
  }) async {
    print('LifterlmsAPI.startQuizAttempt - Starting quiz $quizId for lesson $lessonId');
    
    try {
      final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/mobile-app/quiz/$quizId/start');
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'lesson_id': lessonId,
        }),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      print('LifterlmsAPI.startQuizAttempt - Response: ${response.statusCode}');
      
      return parseResponse(response, url.toString());
    } catch (e) {
      print('LifterlmsAPI.startQuizAttempt - Error: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  // Get quiz questions
  Future<Response> getQuizQuestions({required int quizId}) async {
    print('LifterlmsAPI.getQuizQuestions - Getting questions for quiz $quizId');
    
    try {
      final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/mobile-app/quiz/$quizId/questions');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      print('LifterlmsAPI.getQuizQuestions - Response: ${response.statusCode}');
      
      return parseResponse(response, url.toString());
    } catch (e) {
      print('LifterlmsAPI.getQuizQuestions - Error: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  // Submit quiz attempt
  Future<Response> submitQuizAttempt({
    required int quizId, 
    required int userId,
    required Map<String, dynamic> answers,
  }) async {
    print('LifterlmsAPI.submitQuizAttempt - Quiz: $quizId, User: $userId');
    
    // Placeholder for future implementation
    return const Response(
      statusCode: 501,
      statusText: 'Quiz submission not yet available',
      body: {
        'message': 'Quiz submission coming soon',
      }
    );
  }

  // GET Instructors
  @override
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
  @override
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
  @override
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
  
  // Favorites/Wishlist Methods (use our WordPress plugin)
  @override
  Future<Response> getWishlist({required int userId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/favorites/courses');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      if (response.statusCode == 200) {
        // Parse the response and extract courses
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['courses'] != null) {
          return Response(
            statusCode: 200,
            body: data['courses'],
          );
        }
      }
      
      return parseResponse(response, url.toString());
    } catch (e) {
      print('Error getting wishlist: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> addToWishlist({required int userId, required int courseId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/favorites/add');
    
    print('LifterLMS API - Adding to wishlist');
    print('LifterLMS API - URL: $url');
    print('LifterLMS API - Course ID: $courseId');
    print('LifterLMS API - User ID: $userId');
    
    try {
      // Use Basic Auth only, like the working quiz endpoints
      final headers = {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      };
      final body = jsonEncode({
        'object_id': courseId,
        'object_type': 'course',
      });
      
      print('LifterLMS API - Headers: $headers');
      print('LifterLMS API - Body: $body');
      
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      print('LifterLMS API - Response status: ${response.statusCode}');
      print('LifterLMS API - Response body: ${response.body}');
      
      return parseResponse(response, url.toString());
    } catch (e) {
      print('LifterLMS API - Error adding to wishlist: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> removeFromWishlist({required int userId, required int courseId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/favorites/remove');
    
    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'object_id': courseId,
          'object_type': 'course',
        }),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      print('Error removing from wishlist: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  @override
  Future<Response> isInWishlist({required int userId, required int courseId}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/favorites/check/course/$courseId');
    
    try {
      final response = await http.get(
        url,
        headers: _getAuthenticatedHeaders(),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Response(
          statusCode: 200,
          body: {
            'is_favorite': data['is_favorite'] ?? false,
          },
        );
      }
      
      return parseResponse(response, url.toString());
    } catch (e) {
      print('Error checking wishlist status: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  // Certificate endpoints - using WordPress plugin mobile-app extension
  Future<Response> getCertificates({int page = 1, int limit = 20}) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/mobile-app/certificates?page=$page&limit=$limit');
    
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
      print('Error getting certificates: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  Future<Response> getCertificateDownload(int certificateId) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/mobile-app/certificate/$certificateId/download');
    
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
      print('Error getting certificate download: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  // Submit quiz answer - now properly uses attempt_id
  @override
  Future<Response> submitQuizAnswer({
    required int quizId,
    required int questionId,
    required dynamic answer,
    int? attemptId,  // Made optional for backward compatibility
  }) async {
    // For backward compatibility, attemptId might come from somewhere else
    // But this won't work without it
    if (attemptId == null) {
      print('ERROR: submitQuizAnswer called without attemptId!');
      return const Response(
        statusCode: 400,
        statusText: 'Attempt ID is required'
      );
    }
    
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/mobile-app/quiz/attempt/$attemptId/answer');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'question_id': questionId,
          'answer': answer,
        }),
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      print('Error submitting quiz answer: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
  
  // Complete/finish quiz - properly uses attempt_id
  @override
  Future<Response> finishQuiz({
    required int quizId,
    required int attemptId,
  }) async {
    final url = Uri.parse('$appBaseUrl/wp-json/llms/v1/mobile-app/quiz/attempt/$attemptId/complete');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),  // Empty body for completion
      ).timeout(Duration(seconds: timeoutInSeconds));
      
      return parseResponse(response, url.toString());
    } catch (e) {
      print('Error finishing quiz: $e');
      return const Response(statusCode: 1, statusText: connectionIssue);
    }
  }
}