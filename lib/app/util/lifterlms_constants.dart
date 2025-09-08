import 'package:flutter_app/app/env.dart';

class LifterLMSConstants {
  static const String appName = Environments.appName;
  static const String companyName = Environments.companyName;
  
  // LifterLMS API Configuration
  static const String apiVersion = 'llms/v1';
  static const String apiBase = 'wp-json/llms/v1';
  
  // Authentication
  // These should be stored securely, not hardcoded
  static const String consumerKey = 'YOUR_CONSUMER_KEY';
  static const String consumerSecret = 'YOUR_CONSUMER_SECRET';
  
  // Core API Routes
  static const String courses = '/courses';
  static const String lessons = '/lessons';
  static const String sections = '/sections';
  static const String students = '/students';
  static const String instructors = '/instructors';
  static const String memberships = '/memberships';
  static const String accessPlans = '/access-plans';
  
  // Student-specific routes
  static const String studentEnrollments = '/students/{id}/enrollments';
  static const String studentProgress = '/students/{id}/progress/{post_id}';
  
  // Course-specific routes
  static const String courseEnrollments = '/courses/{id}/enrollments';
  static const String courseContent = '/courses/{id}/content';
  
  // Enrollment statuses
  static const String enrollmentStatusEnrolled = 'enrolled';
  static const String enrollmentStatusExpired = 'expired';
  static const String enrollmentStatusCancelled = 'cancelled';
  
  // Progress statuses
  static const String progressStatusComplete = 'complete';
  static const String progressStatusIncomplete = 'incomplete';
  
  // Currency settings (same as LearnPress)
  static const String defaultCurrencyCode = 'USD';
  static const String defaultCurrencySide = 'right';
  static const String defaultCurrencySymbol = '\$';
  static const String defaultLanguageApp = 'en';
  
  // Pagination defaults
  static const int defaultPerPage = 10;
  static const int maxPerPage = 100;
  
  // Error messages
  static const String errorConnection = 'Connection failed!';
  static const String errorAuthentication = 'Authentication failed!';
  static const String errorNotFound = 'Resource not found!';
  static const String errorPermission = 'You do not have permission to perform this action.';
  
  // Custom endpoints (not part of LifterLMS REST API)
  // These would need to be implemented as custom WordPress endpoints
  static const String wishlist = '/custom/wishlist';
  static const String wishlistToggle = '/custom/wishlist/toggle';
  static const String socialLogin = '/custom/social-login';
  static const String verifyGoogleLogin = '/custom/verify-google';
  static const String verifyAppleLogin = '/custom/verify-apple';
  static const String verifyFacebookLogin = '/custom/verify-facebook';
  
  // Quiz endpoints (not yet available in LifterLMS REST API)
  // Will need custom implementation or wait for official support
  static const String quizStart = '/custom/quiz/start';
  static const String quizFinish = '/custom/quiz/finish';
  static const String quizCheckAnswer = '/custom/quiz/check-answer';
  
  // Assignment endpoints (not yet available in LifterLMS REST API)
  // Will need custom implementation
  static const String assignmentStart = '/custom/assignment/start';
  static const String assignmentSubmit = '/custom/assignment/submit';
  static const String assignmentRetake = '/custom/assignment/retake';
  
  // Helper methods for building URLs
  static String buildStudentEnrollmentsUrl(int studentId) {
    return studentEnrollments.replaceAll('{id}', studentId.toString());
  }
  
  static String buildStudentProgressUrl(int studentId, int postId) {
    return studentProgress
        .replaceAll('{id}', studentId.toString())
        .replaceAll('{post_id}', postId.toString());
  }
  
  static String buildCourseEnrollmentsUrl(int courseId) {
    return courseEnrollments.replaceAll('{id}', courseId.toString());
  }
  
  static String buildCourseContentUrl(int courseId) {
    return courseContent.replaceAll('{id}', courseId.toString());
  }
}