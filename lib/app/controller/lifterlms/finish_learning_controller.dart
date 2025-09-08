import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/helper/dialog_helper.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/util/toast.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class FinishLearningController extends GetxController implements GetxService {
  final LMSService lmsService = LMSService.to;
  
  // Course data
  final Rx<LLMSCourseModel?> course = Rx<LLMSCourseModel?>(null);
  final RxInt courseId = 0.obs;
  final RxString courseName = ''.obs;
  
  // Completion data
  final RxDouble finalGrade = 0.0.obs;
  final RxString gradeStatus = ''.obs; // passed, failed
  final RxDouble completionProgress = 100.0.obs;
  final RxString completionDate = ''.obs;
  final RxInt totalTimeSpent = 0.obs; // in minutes
  
  // Certificate
  final RxBool hasCertificate = false.obs;
  final RxString certificateUrl = ''.obs;
  final RxString certificateId = ''.obs;
  final RxBool isGeneratingCertificate = false.obs;
  
  // Course stats
  final RxInt totalLessons = 0.obs;
  final RxInt completedLessons = 0.obs;
  final RxInt totalQuizzes = 0.obs;
  final RxInt passedQuizzes = 0.obs;
  final RxInt totalAssignments = 0.obs;
  final RxInt completedAssignments = 0.obs;
  
  // Quiz scores
  final RxList<dynamic> quizAttempts = <dynamic>[].obs;
  final RxDouble averageQuizScore = 0.0.obs;
  final RxDouble highestQuizScore = 0.0.obs;
  
  // Achievements
  final RxList<dynamic> earnedAchievements = <dynamic>[].obs;
  final RxList<dynamic> earnedBadges = <dynamic>[].obs;
  final RxInt earnedPoints = 0.obs;
  
  // Next courses
  final RxList<LLMSCourseModel> recommendedCourses = <LLMSCourseModel>[].obs;
  final RxList<LLMSCourseModel> relatedCourses = <LLMSCourseModel>[].obs;
  
  // UI states
  final RxBool isLoading = false.obs;
  final RxBool showConfetti = false.obs;
  final RxInt selectedTab = 0.obs; // 0: Overview, 1: Performance, 2: Certificate, 3: Next Steps
  
  // Feedback
  final RxBool hasRatedCourse = false.obs;
  final RxDouble userRating = 0.0.obs;
  TextEditingController feedbackController = TextEditingController();
  
  @override
  void onInit() {
    super.onInit();
    
    // Get course ID from arguments
    final args = Get.arguments;
    if (args != null && args['course_id'] != null) {
      courseId.value = args['course_id'];
      courseName.value = args['course_name'] ?? '';
      loadCompletionData();
    }
  }
  
  @override
  void onClose() {
    feedbackController.dispose();
    super.onClose();
  }
  
  /// Load completion data
  Future<void> loadCompletionData() async {
    if (!lmsService.isLoggedIn || courseId.value == 0) {
      Get.offNamed(AppRouter.login);
      return;
    }
    
    try {
      isLoading.value = true;
      
      // Load course details
      await loadCourse();
      
      // Load completion details in parallel
      await Future.wait([
        loadCompletionStats(),
        loadQuizPerformance(),
        loadCertificate(),
        loadAchievements(),
        loadRecommendations(),
      ]);
      
      // Show confetti animation for successful completion
      if (gradeStatus.value == 'passed') {
        showConfetti.value = true;
        Future.delayed(Duration(seconds: 5), () {
          showConfetti.value = false;
        });
      }
      
    } catch (e) {
      showToast('Error loading completion data', isError: true);
      print('Error loading completion data: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Load course
  Future<void> loadCourse() async {
    final response = await lmsService.api.getCourse(courseId: courseId.value);
    
    if (response.statusCode == 200) {
      course.value = LLMSCourseModel.fromJson(response.body);
      courseName.value = course.value?.title ?? '';
    }
  }
  
  /// Load completion statistics
  Future<void> loadCompletionStats() async {
    try {
      // Get enrollment data
      final enrollmentResponse = await lmsService.api.getEnrollmentStatus(
        userId: lmsService.currentUserId!,
        courseId: courseId.value,
      );
      
      if (enrollmentResponse.statusCode == 200) {
        final enrollment = enrollmentResponse.body;
        
        // Extract completion data
        completionProgress.value = (enrollment['progress'] ?? 100).toDouble();
        finalGrade.value = (enrollment['grade'] ?? 0).toDouble();
        
        // Determine pass/fail status
        final passingGrade = course.value?.passingPercentage ?? 70;
        gradeStatus.value = finalGrade.value >= passingGrade ? 'passed' : 'failed';
        
        // Get completion date
        if (enrollment['date_completed'] != null) {
          final date = DateTime.parse(enrollment['date_completed']);
          completionDate.value = formatDate(date);
        } else {
          completionDate.value = formatDate(DateTime.now());
        }
        
        // Calculate time spent (would need custom tracking)
        totalTimeSpent.value = enrollment['time_spent'] ?? 0;
      }
      
      // Get progress details
      final progressResponse = await lmsService.getCourseProgress(courseId.value);
      
      if (progressResponse.statusCode == 200) {
        final progress = progressResponse.body;
        
        totalLessons.value = progress['total_lessons'] ?? 0;
        completedLessons.value = progress['completed_lessons'] ?? 0;
        totalQuizzes.value = progress['total_quizzes'] ?? 0;
        passedQuizzes.value = progress['passed_quizzes'] ?? 0;
        totalAssignments.value = progress['total_assignments'] ?? 0;
        completedAssignments.value = progress['completed_assignments'] ?? 0;
      }
      
    } catch (e) {
      print('Error loading completion stats: $e');
    }
  }
  
  /// Load quiz performance
  Future<void> loadQuizPerformance() async {
    try {
      // Get quiz attempts
      final response = await lmsService.api.getStudentQuizAttempts(
        studentId: lmsService.currentUserId!,
        quizId: 0, // TODO: Need to get actual quiz ID
      );
      
      if (response.statusCode == 200) {
        quizAttempts.clear();
        
        if (response.body is List) {
          quizAttempts.addAll(response.body);
          
          // Calculate average and highest scores
          if (quizAttempts.isNotEmpty) {
            double totalScore = 0;
            double highest = 0;
            
            for (var attempt in quizAttempts) {
              final score = (attempt['grade'] ?? 0).toDouble();
              totalScore += score;
              if (score > highest) highest = score;
            }
            
            averageQuizScore.value = totalScore / quizAttempts.length;
            highestQuizScore.value = highest;
          }
        }
      }
    } catch (e) {
      print('Error loading quiz performance: $e');
    }
  }
  
  /// Load certificate
  Future<void> loadCertificate() async {
    try {
      // Check if course has certificate and user earned it
      if (course.value?.hasCertificate != true || gradeStatus.value != 'passed') {
        hasCertificate.value = false;
        return;
      }
      
      // Get certificate
      final response = await lmsService.api.getStudentCertificates(
        studentId: lmsService.currentUserId!,
      );
      
      if (response.statusCode == 200) {
        if (response.body is List && (response.body as List).isNotEmpty) {
          final certificate = response.body[0];
          hasCertificate.value = true;
          certificateId.value = certificate['id'].toString();
          certificateUrl.value = certificate['url'] ?? '';
        } else if (response.body['certificates'] is List) {
          final certificates = response.body['certificates'] as List;
          if (certificates.isNotEmpty) {
            final certificate = certificates[0];
            hasCertificate.value = true;
            certificateId.value = certificate['id'].toString();
            certificateUrl.value = certificate['url'] ?? '';
          }
        }
      } else if (response.statusCode == 404) {
        // Certificate not generated yet
        hasCertificate.value = false;
      }
    } catch (e) {
      print('Error loading certificate: $e');
    }
  }
  
  /// Generate certificate
  Future<void> generateCertificate() async {
    if (gradeStatus.value != 'passed') {
      showToast('You need to pass the course to get a certificate', isError: true);
      return;
    }
    
    try {
      isGeneratingCertificate.value = true;
      DialogHelper.showLoading();
      
      // This would need a custom endpoint to generate certificate
      await Future.delayed(Duration(seconds: 3));
      
      // Simulate certificate generation
      hasCertificate.value = true;
      certificateId.value = 'CERT-${courseId.value}-${lmsService.currentUserId}';
      certificateUrl.value = 'https://example.com/certificate/${certificateId.value}';
      
      DialogHelper.hideLoading();
      showToast('Certificate generated successfully!');
      
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Failed to generate certificate', isError: true);
    } finally {
      isGeneratingCertificate.value = false;
    }
  }
  
  /// Load achievements
  Future<void> loadAchievements() async {
    try {
      // Get course-related achievements
      final response = await lmsService.api.getStudentAchievements(
        studentId: lmsService.currentUserId!,
      );
      
      if (response.statusCode == 200) {
        earnedAchievements.clear();
        earnedBadges.clear();
        
        if (response.body is List) {
          for (var achievement in response.body) {
            if (achievement['type'] == 'badge') {
              earnedBadges.add(achievement);
            } else {
              earnedAchievements.add(achievement);
            }
            earnedPoints.value += (achievement['points'] ?? 0) as int;
          }
        }
      }
      
      // Add completion achievements
      if (gradeStatus.value == 'passed') {
        earnedAchievements.add({
          'title': 'Course Completed',
          'description': 'Successfully completed ${courseName.value}',
          'icon': 'trophy',
          'points': 100,
        });
        
        if (finalGrade.value >= 90) {
          earnedAchievements.add({
            'title': 'Excellence Award',
            'description': 'Scored above 90% in the course',
            'icon': 'star',
            'points': 50,
          });
        }
      }
    } catch (e) {
      print('Error loading achievements: $e');
    }
  }
  
  /// Load recommendations
  Future<void> loadRecommendations() async {
    try {
      // Get recommended courses based on completion
      if (course.value?.categories.isNotEmpty ?? false) {
        final response = await lmsService.api.getCoursesByCategory(
          categoryId: course.value!.categories.first,
          params: {
            'per_page': '6',
            'exclude': courseId.value.toString(),
          },
        );
        
        if (response.statusCode == 200) {
          recommendedCourses.clear();
          relatedCourses.clear();
          
          if (response.body is List) {
            int count = 0;
            for (var courseData in response.body) {
              try {
                final course = LLMSCourseModel.fromJson(courseData);
                if (count < 3) {
                  recommendedCourses.add(course);
                } else {
                  relatedCourses.add(course);
                }
                count++;
              } catch (e) {
                print('Error parsing course: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error loading recommendations: $e');
    }
  }
  
  /// View certificate
  Future<void> viewCertificate() async {
    if (certificateUrl.value.isEmpty) {
      await generateCertificate();
    }
    
    if (certificateUrl.value.isNotEmpty) {
      if (await canLaunch(certificateUrl.value)) {
        await launch(certificateUrl.value);
      } else {
        showToast('Could not open certificate', isError: true);
      }
    }
  }
  
  /// Download certificate
  Future<void> downloadCertificate() async {
    if (certificateUrl.value.isEmpty) {
      await generateCertificate();
    }
    
    if (certificateUrl.value.isNotEmpty) {
      if (await canLaunch(certificateUrl.value)) {
        await launch(certificateUrl.value);
        showToast('Certificate download started');
      } else {
        showToast('Could not download certificate', isError: true);
      }
    }
  }
  
  /// Share certificate
  Future<void> shareCertificate() async {
    if (!hasCertificate.value) {
      showToast('No certificate available to share', isError: true);
      return;
    }
    
    final text = 'I just completed "${courseName.value}" with a ${finalGrade.value.toStringAsFixed(1)}% score! '
                'Check out my certificate: ${certificateUrl.value}';
    
    await Share.share(text);
  }
  
  /// Share achievement
  Future<void> shareAchievement() async {
    final text = 'I just completed "${courseName.value}" with a ${finalGrade.value.toStringAsFixed(1)}% score! '
                '#OnlineLearning #Achievement';
    
    await Share.share(text);
  }
  
  /// Rate course
  Future<void> rateCourse(double rating) async {
    userRating.value = rating;
    hasRatedCourse.value = true;
    
    // Navigate to review page
    Get.toNamed(
      AppRouter.writeReview,
      arguments: {
        'course_id': courseId.value,
        'course_name': courseName.value,
        'initial_rating': rating,
      },
    );
  }
  
  /// Submit feedback
  Future<void> submitFeedback() async {
    if (feedbackController.text.trim().isEmpty) {
      showToast('Please enter your feedback', isError: true);
      return;
    }
    
    try {
      DialogHelper.showLoading();
      
      // This would need a custom endpoint
      await Future.delayed(Duration(seconds: 2));
      
      DialogHelper.hideLoading();
      
      feedbackController.clear();
      showToast('Thank you for your feedback!');
      
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Failed to submit feedback', isError: true);
    }
  }
  
  /// Enroll in recommended course
  void enrollInCourse(int courseId) {
    Get.toNamed(
      AppRouter.getCourseDetail(),
      arguments: {'id': courseId},
    );
  }
  
  /// Continue to next course
  void continueToNextCourse() {
    if (recommendedCourses.isNotEmpty) {
      enrollInCourse(recommendedCourses.first.id);
    } else {
      Get.offAllNamed(AppRouter.courses);
    }
  }
  
  /// Go to my courses
  void goToMyCourses() {
    Get.offAllNamed(AppRouter.myCourses);
  }
  
  /// Go to home
  void goToHome() {
    Get.offAllNamed(AppRouter.home);
  }
  
  /// Change tab
  void changeTab(int index) {
    selectedTab.value = index;
  }
  
  /// Format date
  String formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
  
  /// Format time spent
  String formatTimeSpent() {
    if (totalTimeSpent.value < 60) {
      return '${totalTimeSpent.value} minutes';
    } else {
      final hours = totalTimeSpent.value ~/ 60;
      final minutes = totalTimeSpent.value % 60;
      return '$hours hours $minutes minutes';
    }
  }
  
  /// Get grade color
  Color getGradeColor() {
    if (finalGrade.value >= 90) return Colors.green;
    if (finalGrade.value >= 80) return Colors.lightGreen;
    if (finalGrade.value >= 70) return Colors.orange;
    if (finalGrade.value >= 60) return Colors.deepOrange;
    return Colors.red;
  }
  
  /// Get completion message
  String getCompletionMessage() {
    if (gradeStatus.value == 'passed') {
      if (finalGrade.value >= 90) {
        return 'Outstanding! You\'ve mastered this course!';
      } else if (finalGrade.value >= 80) {
        return 'Great job! You\'ve successfully completed the course!';
      } else {
        return 'Congratulations! You\'ve passed the course!';
      }
    } else {
      return 'Keep trying! You can retake the course to improve your score.';
    }
  }
}