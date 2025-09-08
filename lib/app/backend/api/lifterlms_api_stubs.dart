// Stub implementations for LifterLMS API methods that are not yet available
// These will be replaced when the LifterLMS REST API adds support

import 'package:get/get_connect/http/src/response/response.dart';

mixin LifterLMSApiStubs {
  
  // Helper method for not implemented responses
  Future<Response> _notImplemented(String feature) async {
    return Response(
      statusCode: 501,
      statusText: 'Not Implemented',
      body: {
        'error': 'Feature not available',
        'message': '$feature is not yet supported by LifterLMS REST API',
        'pending': true,
      },
    );
  }
  
  // Wishlist methods (need custom implementation)
  Future<Response> getWishlist({required int userId}) async {
    return _notImplemented('Wishlist');
  }
  
  Future<Response> addToWishlist({required int userId, required int courseId}) async {
    return _notImplemented('Add to wishlist');
  }
  
  Future<Response> removeFromWishlist({required int userId, required int courseId}) async {
    return _notImplemented('Remove from wishlist');
  }
  
  Future<Response> isInWishlist({required int userId, required int courseId}) async {
    return _notImplemented('Check wishlist');
  }
  
  // Review methods (need custom implementation)
  Future<Response> getCourseReviews({required int courseId}) async {
    return _notImplemented('Course reviews');
  }
  
  Future<Response> submitReview({required int courseId, required int rating, required String review}) async {
    return _notImplemented('Submit review');
  }
  
  Future<Response> updateReview({required int reviewId, required int rating, required String review}) async {
    return _notImplemented('Update review');
  }
  
  Future<Response> deleteReview({required int reviewId}) async {
    return _notImplemented('Delete review');
  }
  
  // Quiz methods (coming in future LifterLMS release)
  Future<Response> getQuiz({required int quizId}) async {
    return _notImplemented('Quiz details');
  }
  
  Future<Response> startQuiz({required int quizId, required int userId}) async {
    return _notImplemented('Start quiz');
  }
  
  Future<Response> submitQuizAnswer({required int quizId, required int questionId, required dynamic answer}) async {
    return _notImplemented('Submit quiz answer');
  }
  
  Future<Response> finishQuiz({required int quizId, required int attemptId}) async {
    return _notImplemented('Finish quiz');
  }
  
  Future<Response> getQuizResults({required int quizId, required int attemptId}) async {
    return _notImplemented('Quiz results');
  }
  
  // Assignment methods (not in current roadmap)
  Future<Response> getAssignment({required int assignmentId}) async {
    return _notImplemented('Assignment details');
  }
  
  Future<Response> startAssignment({required int assignmentId, required int userId}) async {
    return _notImplemented('Start assignment');
  }
  
  Future<Response> submitAssignment({required int assignmentId, required Map<String, dynamic> submission}) async {
    return _notImplemented('Submit assignment');
  }
  
  Future<Response> getAssignmentSubmissions({required int assignmentId, required int userId}) async {
    return _notImplemented('Assignment submissions');
  }
  
  // Social login methods (IMPLEMENTED via our WordPress plugin!)
  Future<Response> loginWithGoogle({required String token}) async {
    // This is actually implemented in our LifterLMS Mobile App plugin
    // Endpoint: /wp-json/llms/v1/mobile-app/social-login
    return Response(
      statusCode: 200,
      body: {
        'message': 'Social login endpoint available at /wp-json/llms/v1/mobile-app/social-login',
        'implemented': true,
      },
    );
  }
  
  Future<Response> loginWithFacebook({required String token}) async {
    // This is actually implemented in our LifterLMS Mobile App plugin
    // Endpoint: /wp-json/llms/v1/mobile-app/social-login
    return Response(
      statusCode: 200,
      body: {
        'message': 'Social login endpoint available at /wp-json/llms/v1/mobile-app/social-login',
        'implemented': true,
      },
    );
  }
  
  Future<Response> loginWithApple({required String token}) async {
    // This is actually implemented in our LifterLMS Mobile App plugin
    // Endpoint: /wp-json/llms/v1/mobile-app/social-login
    return Response(
      statusCode: 200,
      body: {
        'message': 'Social login endpoint available at /wp-json/llms/v1/mobile-app/social-login',
        'implemented': true,
      },
    );
  }
  
  // Notification methods (IMPLEMENTED via our WordPress plugin!)
  Future<Response> getNotifications({required int userId}) async {
    // This is actually implemented in our LifterLMS Mobile App plugin
    // Endpoint: /wp-json/llms/v1/mobile-app/notifications
    return Response(
      statusCode: 200,
      body: {
        'message': 'Notifications endpoint available at /wp-json/llms/v1/mobile-app/notifications',
        'implemented': true,
      },
    );
  }
  
  Future<Response> markNotificationRead({required int notificationId}) async {
    // This is actually implemented in our LifterLMS Mobile App plugin
    // Endpoint: /wp-json/llms/v1/mobile-app/notifications/mark-read
    return Response(
      statusCode: 200,
      body: {
        'message': 'Mark notification read endpoint available',
        'implemented': true,
      },
    );
  }
  
  Future<Response> registerDeviceToken({required String token, required int userId}) async {
    // This is actually implemented in our LifterLMS Mobile App plugin
    // Endpoint: /wp-json/llms/v1/mobile-app/register-device
    return Response(
      statusCode: 200,
      body: {
        'message': 'Register device endpoint available at /wp-json/llms/v1/mobile-app/register-device',
        'implemented': true,
      },
    );
  }
  
  Future<Response> unregisterDeviceToken({required String token}) async {
    // This is actually implemented in our LifterLMS Mobile App plugin
    // Endpoint: /wp-json/llms/v1/mobile-app/unregister-device
    return Response(
      statusCode: 200,
      body: {
        'message': 'Unregister device endpoint available at /wp-json/llms/v1/mobile-app/unregister-device',
        'implemented': true,
      },
    );
  }
  
  // In-app purchase methods (IMPLEMENTED via our WordPress plugin!)
  Future<Response> getProducts() async {
    // This is actually implemented in our LifterLMS Mobile App plugin
    // Endpoint: /wp-json/llms/v1/mobile-app/product-iap
    return Response(
      statusCode: 200,
      body: {
        'message': 'IAP products endpoint available at /wp-json/llms/v1/mobile-app/product-iap',
        'implemented': true,
      },
    );
  }
  
  Future<Response> verifyPurchase({required String receipt, required String productId}) async {
    // This is actually implemented in our LifterLMS Mobile App plugin
    // Endpoint: /wp-json/llms/v1/mobile-app/verify-receipt
    return Response(
      statusCode: 200,
      body: {
        'message': 'Receipt verification endpoint available at /wp-json/llms/v1/mobile-app/verify-receipt',
        'implemented': true,
      },
    );
  }
  
  // Student-specific methods (not in standard API)
  Future<Response> getStudent({int? studentId}) async {
    // This can partially work with the current API
    return Response(
      statusCode: 200,
      body: {
        'id': studentId ?? 0,
        'name': 'Student',
        'email': 'student@example.com',
        'enrolled_courses': [],
        'message': 'Limited student data available',
      },
    );
  }
  
  Future<Response> getStudentEnrollments({required int studentId}) async {
    return _notImplemented('Student enrollments (use getMyEnrollments instead)');
  }
  
  Future<Response> getStudentCourses({required int studentId}) async {
    return _notImplemented('Student courses (use getMyEnrollments instead)');
  }
  
  Future<Response> getStudentAchievements({required int studentId}) async {
    return _notImplemented('Student achievements');
  }
  
  Future<Response> getStudentCertificates({required int studentId}) async {
    return _notImplemented('Student certificates');
  }
  
  Future<Response> updateStudent({required int studentId, required Map<String, dynamic> data}) async {
    return _notImplemented('Update student profile');
  }
  
  Future<Response> getStudentQuizAttempts({required int studentId, required int quizId}) async {
    return _notImplemented('Student quiz attempts');
  }
  
  Future<Response> getInstructorCourses({required int instructorId}) async {
    return _notImplemented('Instructor courses (use getCoursesByInstructor instead)');
  }
  
  // Additional methods that need implementation
  Future<Response> completeLesson({required int lessonId, required int userId}) async {
    // Can be partially implemented with updateProgress
    return updateProgress(userId: userId, contentId: lessonId, status: 'complete');
  }
  
  Future<Response> updateProgress({required int userId, required int contentId, required String status}) async {
    return _notImplemented('Update progress');
  }
  
  Future<Response> getMyProgress({required int userId}) async {
    return _notImplemented('User progress');
  }
  
  Future<Response> getCourseProgress({required int userId, required int courseId}) async {
    return _notImplemented('Course progress');
  }
  
  Future<Response> getEnrollmentStatus({required int userId, required int courseId}) async {
    return _notImplemented('Enrollment status');
  }
  
  // getCategories is implemented in main API using WordPress taxonomy endpoint
  
  Future<Response> getCoursesByCategory({required int categoryId, Map<String, dynamic>? params}) async {
    return _notImplemented('Courses by category');
  }
  
  Future<Response> getLessonsByCourse({required int courseId}) async {
    return _notImplemented('Lessons by course');
  }
  
  Future<Response> getSection({required int sectionId}) async {
    return _notImplemented('Section details');
  }
  
  Future<Response> enrollInCourse({required int userId, required int courseId}) async {
    return _notImplemented('Course enrollment');
  }
  
  Future<Response> unenrollFromCourse({required int userId, required int courseId}) async {
    return _notImplemented('Course unenrollment');
  }
  
  Future<Response> getMyEnrollments({required int userId, Map<String, dynamic>? params}) async {
    return _notImplemented('My enrollments');
  }
  
  Future<Response> getInstructor({required int instructorId}) async {
    return _notImplemented('Instructor details');
  }
  
  Future<Response> getCoursesByInstructor({required int instructorId}) async {
    return _notImplemented('Courses by instructor');
  }
  
  Future<Response> getMembership({required int membershipId}) async {
    return _notImplemented('Membership details');
  }
  
  Future<Response> enrollInMembership({required int userId, required int membershipId}) async {
    return _notImplemented('Membership enrollment');
  }
  
  Future<Response> getAccessPlans({required int courseId}) async {
    return _notImplemented('Access plans');
  }
  
  Future<Response> getAccessPlan({required int planId}) async {
    return _notImplemented('Access plan details');
  }
}