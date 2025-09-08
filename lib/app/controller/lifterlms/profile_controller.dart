import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/util/toast.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileController extends GetxController implements GetxService {
  final LMSService lmsService = LMSService.to;
  
  // User profile data
  final RxMap<String, dynamic> userProfile = <String, dynamic>{}.obs;
  final RxString displayName = ''.obs;
  final RxString email = ''.obs;
  final RxString avatarUrl = ''.obs;
  final RxString bio = ''.obs;
  final RxString memberSince = ''.obs;
  
  // User stats
  final RxInt enrolledCourses = 0.obs;
  final RxInt completedCourses = 0.obs;
  final RxInt certificates = 0.obs;
  final RxInt achievements = 0.obs;
  final RxDouble overallProgress = 0.0.obs;
  final RxInt totalPoints = 0.obs;
  final RxString currentLevel = 'Beginner'.obs;
  
  // User courses
  final RxList<LLMSCourseModel> userCourses = <LLMSCourseModel>[].obs;
  final RxList<dynamic> userCertificates = <dynamic>[].obs;
  final RxList<dynamic> userAchievements = <dynamic>[].obs;
  final RxList<dynamic> userBadges = <dynamic>[].obs;
  
  // UI states
  final RxBool isLoading = false.obs;
  final RxBool isOwnProfile = false.obs;
  final RxInt selectedTab = 0.obs; // 0: Overview, 1: Courses, 2: Achievements, 3: Certificates
  
  // Social links
  final RxMap<String, String> socialLinks = <String, String>{}.obs;
  
  int userId = 0;
  
  @override
  void onInit() {
    super.onInit();
    // Get user ID from arguments or use current user
    final args = Get.arguments;
    if (args != null && args is Map && args['user_id'] != null) {
      userId = args['user_id'];
      isOwnProfile.value = (userId == lmsService.currentUserId);
    } else {
      // Default to current user profile
      userId = lmsService.currentUserId ?? 0;
      isOwnProfile.value = true;
    }
    
    if (userId != 0) {
      loadUserProfile();
    } else if (!lmsService.isLoggedIn) {
      // Redirect to login if not logged in
      Get.offNamed(AppRouter.login);
    }
  }
  
  /// Load user profile
  Future<void> loadUserProfile() async {
    if (userId == 0) {
      showToast('Invalid user ID', isError: true);
      return;
    }
    
    try {
      isLoading.value = true;
      
      // Load user data
      final response = await lmsService.api.getStudent(studentId: userId);
      
      if (response.statusCode == 200) {
        userProfile.value = response.body;
        
        // Extract user info
        displayName.value = userProfile['display_name'] ?? userProfile['name'] ?? '';
        email.value = userProfile['email'] ?? '';
        avatarUrl.value = userProfile['avatar_url'] ?? '';
        bio.value = userProfile['description'] ?? userProfile['bio'] ?? '';
        
        // Format registration date
        if (userProfile['registered'] != null) {
          final date = DateTime.parse(userProfile['registered']);
          memberSince.value = formatDate(date);
        }
        
        // Load additional data
        await Future.wait([
          loadUserStats(),
          loadUserCourses(),
          loadUserAchievements(),
          loadUserCertificates(),
        ]);
        
        // Extract social links
        extractSocialLinks();
        
      } else if (response.statusCode == 404) {
        showToast('User not found', isError: true);
        Get.back();
      } else {
        showToast('Failed to load profile', isError: true);
      }
    } catch (e) {
      showToast('Error loading profile', isError: true);
      print('Error loading profile: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Load user statistics
  Future<void> loadUserStats() async {
    try {
      // Get enrollment stats
      final enrollmentResponse = await lmsService.api.getStudentEnrollments(
        studentId: userId,
      );
      
      if (enrollmentResponse.statusCode == 200 && enrollmentResponse.body is List) {
        final enrollments = enrollmentResponse.body as List;
        enrolledCourses.value = enrollments.length;
        
        // Calculate completed courses
        int completed = 0;
        double totalProgress = 0.0;
        
        for (var enrollment in enrollments) {
          final progress = (enrollment['progress'] ?? 0).toDouble();
          totalProgress += progress;
          if (progress >= 100) {
            completed++;
          }
        }
        
        completedCourses.value = completed;
        if (enrollments.isNotEmpty) {
          overallProgress.value = totalProgress / enrollments.length;
        }
      }
      
      // Get achievements count
      final achievementsResponse = await lmsService.api.getStudentAchievements(
        studentId: userId,
      );
      
      if (achievementsResponse.statusCode == 200) {
        if (achievementsResponse.body is List) {
          achievements.value = (achievementsResponse.body as List).length;
        } else if (achievementsResponse.body['achievements'] is List) {
          achievements.value = (achievementsResponse.body['achievements'] as List).length;
        }
      }
      
      // Get certificates count
      final certificatesResponse = await lmsService.api.getStudentCertificates(
        studentId: userId,
      );
      
      if (certificatesResponse.statusCode == 200) {
        if (certificatesResponse.body is List) {
          certificates.value = (certificatesResponse.body as List).length;
        } else if (certificatesResponse.body['certificates'] is List) {
          certificates.value = (certificatesResponse.body['certificates'] as List).length;
        }
      }
      
      // Calculate user level based on points or completed courses
      calculateUserLevel();
      
    } catch (e) {
      print('Error loading user stats: $e');
    }
  }
  
  /// Load user courses
  Future<void> loadUserCourses() async {
    try {
      final response = await lmsService.api.getStudentCourses(
        studentId: userId,
      );
      
      if (response.statusCode == 200) {
        userCourses.clear();
        if (response.body is List) {
          for (var courseData in response.body) {
            try {
              final course = LLMSCourseModel.fromJson(courseData);
              userCourses.add(course);
            } catch (e) {
              print('Error parsing course: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error loading user courses: $e');
    }
  }
  
  /// Load user achievements
  Future<void> loadUserAchievements() async {
    try {
      final response = await lmsService.api.getStudentAchievements(
        studentId: userId,
      );
      
      if (response.statusCode == 200) {
        userAchievements.clear();
        userBadges.clear();
        
        if (response.body is List) {
          userAchievements.addAll(response.body);
        } else if (response.body['achievements'] is List) {
          userAchievements.addAll(response.body['achievements']);
        }
        
        // Separate badges from achievements
        for (var achievement in userAchievements) {
          if (achievement['type'] == 'badge') {
            userBadges.add(achievement);
          }
        }
      }
    } catch (e) {
      print('Error loading achievements: $e');
    }
  }
  
  /// Load user certificates
  Future<void> loadUserCertificates() async {
    try {
      final response = await lmsService.api.getStudentCertificates(
        studentId: userId,
      );
      
      if (response.statusCode == 200) {
        userCertificates.clear();
        
        if (response.body is List) {
          userCertificates.addAll(response.body);
        } else if (response.body['certificates'] is List) {
          userCertificates.addAll(response.body['certificates']);
        }
      }
    } catch (e) {
      print('Error loading certificates: $e');
    }
  }
  
  /// Calculate user level based on activity
  void calculateUserLevel() {
    // Simple level calculation based on completed courses
    if (completedCourses.value == 0) {
      currentLevel.value = 'Beginner';
      totalPoints.value = 0;
    } else if (completedCourses.value < 3) {
      currentLevel.value = 'Intermediate';
      totalPoints.value = completedCourses.value * 100;
    } else if (completedCourses.value < 10) {
      currentLevel.value = 'Advanced';
      totalPoints.value = completedCourses.value * 150;
    } else {
      currentLevel.value = 'Expert';
      totalPoints.value = completedCourses.value * 200;
    }
    
    // Add achievement points
    totalPoints.value += achievements.value * 50;
    totalPoints.value += certificates.value * 75;
  }
  
  /// Extract social links from profile
  void extractSocialLinks() {
    socialLinks.clear();
    
    if (userProfile['website'] != null) {
      socialLinks['website'] = userProfile['website'];
    }
    
    // Check meta fields for social links
    if (userProfile['meta'] != null) {
      final meta = userProfile['meta'];
      if (meta['facebook'] != null) socialLinks['facebook'] = meta['facebook'];
      if (meta['twitter'] != null) socialLinks['twitter'] = meta['twitter'];
      if (meta['linkedin'] != null) socialLinks['linkedin'] = meta['linkedin'];
      if (meta['instagram'] != null) socialLinks['instagram'] = meta['instagram'];
      if (meta['youtube'] != null) socialLinks['youtube'] = meta['youtube'];
    }
  }
  
  /// Change tab
  void changeTab(int index) {
    selectedTab.value = index;
  }
  
  /// Navigate to course detail
  void goToCourseDetail(int courseId) {
    Get.toNamed(
      AppRouter.getCourseDetail(),
      arguments: {'id': courseId},
    );
  }
  
  /// View certificate
  Future<void> viewCertificate(dynamic certificate) async {
    if (certificate['url'] != null) {
      final url = certificate['url'];
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        showToast('Could not open certificate', isError: true);
      }
    } else {
      showToast('Certificate not available', isError: true);
    }
  }
  
  /// Download certificate
  Future<void> downloadCertificate(dynamic certificate) async {
    if (certificate['download_url'] != null) {
      final url = certificate['download_url'];
      if (await canLaunch(url)) {
        await launch(url);
        showToast('Certificate download started');
      } else {
        showToast('Could not download certificate', isError: true);
      }
    } else {
      viewCertificate(certificate);
    }
  }
  
  /// Share achievement
  void shareAchievement(dynamic achievement) {
    final text = 'I just earned "${achievement['title']}" on our learning platform!';
    // Share.share(text);
    showToast('Share feature coming soon');
  }
  
  /// Open social link
  Future<void> openSocialLink(String platform) async {
    final url = socialLinks[platform];
    if (url == null) return;
    
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      showToast('Could not open $platform link', isError: true);
    }
  }
  
  /// Navigate to edit profile
  void editProfile() {
    if (isOwnProfile.value) {
      Get.toNamed(AppRouter.myProfile);
    } else {
      showToast('You can only edit your own profile', isError: true);
    }
  }
  
  /// Message user
  void messageUser() {
    if (!isOwnProfile.value) {
      // Navigate to messaging or show contact options
      showToast('Messaging feature coming soon');
    }
  }
  
  /// Refresh profile
  Future<void> refreshProfile() async {
    await loadUserProfile();
  }
  
  /// Format date
  String formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
  
  /// Get progress color
  Color getProgressColor(double progress) {
    if (progress < 30) return Colors.red;
    if (progress < 60) return Colors.orange;
    if (progress < 90) return Colors.blue;
    return Colors.green;
  }
  
  /// Logout user (for compatibility with settings_controller)
  Future<void> logout() async {
    try {
      // Show loading
      Get.dialog(
        Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );
      
      // Clear session
      await lmsService.logout();
      
      // Close loading dialog
      Get.back();
      
      // Navigate to login
      Get.offAllNamed(AppRouter.login);
      
      showToast('Logged out successfully');
    } catch (e) {
      Get.back(); // Close loading if still open
      showToast('Error logging out: $e', isError: true);
    }
  }
  
  /// Get level color
  Color getLevelColor() {
    switch (currentLevel.value) {
      case 'Expert':
        return Colors.purple;
      case 'Advanced':
        return Colors.blue;
      case 'Intermediate':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}