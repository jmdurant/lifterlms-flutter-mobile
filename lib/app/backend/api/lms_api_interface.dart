import 'package:get/get.dart';

/// Abstract interface for LMS API operations
/// This allows us to swap between different LMS implementations
abstract class LMSApiInterface {
  // Authentication
  Future<Response> login({required String username, required String password});
  Future<Response> register({required Map<String, dynamic> userData});
  Future<Response> forgotPassword({required String email});
  Future<Response> changePassword({required String oldPassword, required String newPassword});
  
  // User Management
  Future<Response> getCurrentUser();
  Future<Response> updateUser({required int userId, required Map<String, dynamic> userData});
  Future<Response> deleteUser({required int userId});
  
  // Courses
  Future<Response> getCourses({Map<String, dynamic>? params});
  Future<Response> getCourse({required int courseId});
  Future<Response> getPopularCourses({int page = 1, int perPage = 10});
  Future<Response> getNewCourses({int page = 1, int perPage = 10});
  Future<Response> searchCourses({required String query, Map<String, dynamic>? params});
  
  // Categories
  Future<Response> getCategories({Map<String, dynamic>? params});
  Future<Response> getCoursesByCategory({required int categoryId, Map<String, dynamic>? params});
  
  // Lessons
  Future<Response> getLesson({required int lessonId});
  Future<Response> getLessonsByCourse({required int courseId});
  Future<Response> completeLesson({required int lessonId, required int userId});
  
  // Sections
  Future<Response> getSections({required int courseId});
  Future<Response> getSection({required int sectionId});
  
  // Enrollments
  Future<Response> enrollInCourse({required int userId, required int courseId});
  Future<Response> unenrollFromCourse({required int userId, required int courseId});
  Future<Response> getMyEnrollments({required int userId, Map<String, dynamic>? params});
  Future<Response> getEnrollmentStatus({required int userId, required int courseId});
  
  // Progress
  Future<Response> getCourseProgress({required int userId, required int courseId});
  Future<Response> updateProgress({required int userId, required int contentId, required String status});
  Future<Response> getMyProgress({required int userId});
  
  // Instructors
  Future<Response> getInstructors({Map<String, dynamic>? params});
  Future<Response> getUsers({Map<String, dynamic>? params});
  Future<Response> getInstructor({required int instructorId});
  Future<Response> getCoursesByInstructor({required int instructorId});
  
  // Media
  Future<Response> getMedia({required int mediaId});
  Future<Response> getOEmbedData({required String courseUrl});
  
  // Reviews/Ratings
  Future<Response> getCourseReviews({required int courseId});
  Future<Response> submitReview({required int courseId, required int rating, required String review});
  Future<Response> updateReview({required int reviewId, required int rating, required String review});
  Future<Response> deleteReview({required int reviewId});
  
  // Wishlist (Custom Implementation Required)
  Future<Response> getWishlist({required int userId});
  Future<Response> addToWishlist({required int userId, required int courseId});
  Future<Response> removeFromWishlist({required int userId, required int courseId});
  Future<Response> isInWishlist({required int userId, required int courseId});
  
  // Notifications
  Future<Response> getNotifications({required int userId});
  Future<Response> markNotificationRead({required int notificationId});
  Future<Response> registerDeviceToken({required String token, required int userId});
  Future<Response> unregisterDeviceToken({required String token});
  
  // Quiz (Custom Implementation Required for LifterLMS)
  Future<Response> getQuiz({required int quizId});
  Future<Response> startQuiz({required int quizId, required int userId});
  Future<Response> submitQuizAnswer({required int quizId, required int questionId, required dynamic answer});
  Future<Response> finishQuiz({required int quizId, required int attemptId});
  Future<Response> getQuizResults({required int quizId, required int attemptId});
  
  // Assignments (Custom Implementation Required for LifterLMS)
  Future<Response> getAssignment({required int assignmentId});
  Future<Response> startAssignment({required int assignmentId, required int userId});
  Future<Response> submitAssignment({required int assignmentId, required Map<String, dynamic> submission});
  Future<Response> getAssignmentSubmissions({required int assignmentId, required int userId});
  
  // Memberships (LifterLMS Specific)
  Future<Response> getMemberships({Map<String, dynamic>? params});
  Future<Response> getMembership({required int membershipId});
  Future<Response> enrollInMembership({required int userId, required int membershipId});
  
  // Access Plans (LifterLMS Specific)
  Future<Response> getAccessPlans({required int courseId});
  Future<Response> getAccessPlan({required int planId});
  
  // In-App Purchases
  Future<Response> verifyPurchase({required String receipt, required String productId});
  Future<Response> getProducts();
  
  // Social Login (Custom Implementation)
  Future<Response> loginWithGoogle({required String token});
  Future<Response> loginWithFacebook({required String token});
  Future<Response> loginWithApple({required String token});
  
  // Student-specific methods (Not in standard API, need custom implementation)
  Future<Response> getStudent({int? studentId});
  Future<Response> getStudentEnrollments({required int studentId});
  Future<Response> getStudentCourses({required int studentId});
  Future<Response> getStudentAchievements({required int studentId});
  Future<Response> getStudentCertificates({required int studentId});
  Future<Response> updateStudent({required int studentId, required Map<String, dynamic> data});
  Future<Response> getStudentQuizAttempts({required int studentId, required int quizId});
  Future<Response> getInstructorCourses({required int instructorId});
}

/// Response model for API calls
class LMSResponse {
  final bool success;
  final dynamic data;
  final String? message;
  final int? statusCode;
  final Map<String, dynamic>? metadata;
  
  LMSResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
    this.metadata,
  });
  
  factory LMSResponse.fromGetResponse(Response response) {
    return LMSResponse(
      success: response.statusCode == 200 || response.statusCode == 201,
      data: response.body,
      message: response.statusText,
      statusCode: response.statusCode,
      metadata: response.headers,
    );
  }
}