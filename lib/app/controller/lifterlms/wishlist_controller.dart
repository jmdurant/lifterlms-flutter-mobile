import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/helper/dialog_helper.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/util/toast.dart';
import 'package:get/get.dart';

class WishlistController extends GetxController implements GetxService {
  final LMSService lmsService = LMSService.to;
  
  // Observable lists
  final RxList<LLMSCourseModel> _wishlistCourses = <LLMSCourseModel>[].obs;
  
  // Getters
  List<LLMSCourseModel> get wishlistCourses => _wishlistCourses;
  
  // Loading states
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  
  // Pagination
  final RxInt currentPage = 1.obs;
  final RxBool hasMoreData = true.obs;
  final int perPage = 10;
  
  // Error handling
  final RxString errorMessage = ''.obs;
  final RxBool hasError = false.obs;
  
  // Scroll controller for pagination
  ScrollController scrollController = ScrollController();
  
  // Track wishlist status for quick access
  final RxSet<int> wishlistIds = <int>{}.obs;
  
  @override
  void onInit() {
    super.onInit();
    initializeScrollListener();
    if (lmsService.isLoggedIn) {
      loadWishlist();
    }
  }
  
  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
  
  /// Initialize scroll listener for pagination
  void initializeScrollListener() {
    scrollController.addListener(() {
      if (scrollController.position.pixels >= 
          scrollController.position.maxScrollExtent - 200) {
        if (!isLoadingMore.value && hasMoreData.value) {
          loadMoreWishlist();
        }
      }
    });
  }
  
  /// Load wishlist courses
  Future<void> loadWishlist({bool isRefresh = false}) async {
    if (!lmsService.isLoggedIn) {
      _handleError('Please login to view wishlist');
      return;
    }
    
    if (isRefresh) {
      currentPage.value = 1;
      hasMoreData.value = true;
      _wishlistCourses.clear();
      wishlistIds.clear();
    }
    
    try {
      isLoading.value = true;
      errorMessage.value = '';
      hasError.value = false;
      
      // Note: Wishlist is a custom feature not in LifterLMS core
      // This will use the custom endpoint if implemented
      final response = await lmsService.getWishlist();
      
      if (response.statusCode == 200) {
        if (response.body is List) {
          for (var courseData in response.body) {
            try {
              final course = LLMSCourseModel.fromJson(courseData);
              _wishlistCourses.add(course);
              wishlistIds.add(course.id);
            } catch (e) {
              print('Error parsing wishlist course: $e');
            }
          }
          
          // Check if there's more data
          if ((response.body as List).length < perPage) {
            hasMoreData.value = false;
          }
        }
      } else if (response.statusCode == 501) {
        // Wishlist not implemented
        _showWishlistNotAvailable();
      } else {
        _handleError('Failed to load wishlist');
      }
    } catch (e) {
      _handleError('Error loading wishlist: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Load more wishlist items (pagination)
  Future<void> loadMoreWishlist() async {
    if (isLoadingMore.value || !hasMoreData.value) return;
    
    try {
      isLoadingMore.value = true;
      currentPage.value++;
      
      // Load more items with pagination
      await loadWishlist();
    } finally {
      isLoadingMore.value = false;
    }
  }
  
  /// Add course to wishlist
  Future<void> addToWishlist(int courseId) async {
    print('WishlistController - Adding course $courseId to wishlist');
    
    if (!lmsService.isLoggedIn) {
      print('WishlistController - User not logged in');
      Get.toNamed(AppRouter.login);
      return;
    }
    
    // Optimistically add to wishlist for immediate visual feedback
    wishlistIds.add(courseId);
    update(); // Update ALL widgets listening to this controller
    
    try {
      // No loading dialog for better UX
      print('WishlistController - Calling API to add course $courseId');
      final response = await lmsService.addToWishlist(courseId);
      
      print('WishlistController - API Response: ${response.statusCode}');
      print('WishlistController - API Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success - already added to local list
        // Fetch course details and add to list
        await _fetchAndAddCourse(courseId);
      } else {
        // Failed - revert the optimistic update
        wishlistIds.remove(courseId);
        update(); // Update ALL widgets
        
        if (response.statusCode == 501) {
          print('WishlistController - Wishlist not available (501)');
          _showWishlistNotAvailable();
        } else {
          print('WishlistController - Failed with status: ${response.statusCode}');
        }
      }
    } catch (e) {
      // Failed - revert the optimistic update
      wishlistIds.remove(courseId);
      update(); // Update ALL widgets
      print('WishlistController - Exception: $e');
    }
  }
  
  /// Remove course from wishlist
  Future<void> removeFromWishlist(int courseId) async {
    if (!lmsService.isLoggedIn) return;
    
    // Optimistically remove from wishlist for immediate visual feedback
    wishlistIds.remove(courseId);
    _wishlistCourses.removeWhere((course) => course.id == courseId);
    update(); // Update ALL widgets
    
    try {
      // No loading dialog for better UX
      final response = await lmsService.removeFromWishlist(courseId);
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        // Success - already removed from local lists
      } else {
        // Failed - revert the optimistic update
        wishlistIds.add(courseId);
        // Re-fetch the course to add it back to the list
        await _fetchAndAddCourse(courseId);
        update(); // Update ALL widgets
        
        if (response.statusCode == 501) {
          _showWishlistNotAvailable();
        } else {
          print('Failed to remove from wishlist: ${response.statusCode}');
        }
      }
    } catch (e) {
      // Failed - revert the optimistic update
      wishlistIds.add(courseId);
      await _fetchAndAddCourse(courseId);
      update(); // Update ALL widgets
      print('Error removing from wishlist: $e');
    }
  }
  
  /// Toggle wishlist status
  Future<void> toggleWishlist(int courseId) async {
    if (isInWishlist(courseId)) {
      await removeFromWishlist(courseId);
    } else {
      await addToWishlist(courseId);
    }
  }
  
  /// Check if course is in wishlist
  bool isInWishlist(int courseId) {
    return wishlistIds.contains(courseId);
  }
  
  /// Fetch course details and add to wishlist
  Future<void> _fetchAndAddCourse(int courseId) async {
    try {
      final response = await lmsService.api.getCourse(courseId: courseId);
      
      if (response.statusCode == 200) {
        final course = LLMSCourseModel.fromJson(response.body);
        
        // Check if not already in list
        if (!_wishlistCourses.any((c) => c.id == courseId)) {
          _wishlistCourses.add(course);
        }
      }
    } catch (e) {
      print('Error fetching course for wishlist: $e');
    }
  }
  
  /// Navigate to course detail
  void goToCourseDetail(int courseId) {
    Get.toNamed(
      AppRouter.getCourseDetail(),
      arguments: {'id': courseId},
    );
  }
  
  /// Enroll in course from wishlist
  Future<void> enrollInCourse(int courseId) async {
    if (!lmsService.isLoggedIn) {
      Get.toNamed(AppRouter.login);
      return;
    }
    
    try {
      DialogHelper.showLoading();
      
      final response = await lmsService.enrollInCourse(courseId);
      
      DialogHelper.hideLoading();
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Remove from wishlist after enrollment
        await removeFromWishlist(courseId);
        
        showToast('Successfully enrolled in course');
        
        // Navigate to learning page
        Get.toNamed(
          AppRouter.getLearning(),
          arguments: {'id': courseId},
        );
      } else {
        showToast(
          response.body?['message'] ?? 'Failed to enroll in course',
          isError: true
        );
      }
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Error enrolling in course', isError: true);
    }
  }
  
  /// Clear wishlist
  Future<void> clearWishlist() async {
    Get.dialog(
      AlertDialog(
        title: Text('Clear Wishlist'),
        content: Text('Are you sure you want to remove all courses from your wishlist?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await _performClearWishlist();
            },
            child: Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  /// Perform clear wishlist
  Future<void> _performClearWishlist() async {
    try {
      DialogHelper.showLoading();
      
      // Remove each course from wishlist
      for (var course in _wishlistCourses) {
        await lmsService.removeFromWishlist(course.id);
      }
      
      // Clear local data
      _wishlistCourses.clear();
      wishlistIds.clear();
      
      DialogHelper.hideLoading();
      showToast('Wishlist cleared');
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Error clearing wishlist', isError: true);
    }
  }
  
  /// Refresh wishlist
  Future<void> refreshWishlist() async {
    currentPage.value = 1;
    hasMoreData.value = true;
    await loadWishlist(isRefresh: true);
  }
  
  /// Show wishlist not available message
  void _showWishlistNotAvailable() {
    Get.dialog(
      AlertDialog(
        title: Text('Favorites Not Available'),
        content: Text(
          'The favorites feature is not yet available on your LifterLMS site. '
          'Please contact your site administrator to enable this feature.'
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Handle errors
  void _handleError(String message) {
    errorMessage.value = message;
    hasError.value = true;
    print(message);
  }
  
  /// Clear error
  void clearError() {
    errorMessage.value = '';
    hasError.value = false;
  }
  
  /// Get wishlist count
  int get wishlistCount => _wishlistCourses.length;
  
  /// Check if wishlist is empty
  bool get isWishlistEmpty => _wishlistCourses.isEmpty;
}