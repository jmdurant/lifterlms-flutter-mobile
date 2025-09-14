import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_instructor_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_category_model.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/backend/services/media_cache_service.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/helper/shared_pref.dart';
import 'package:get/get.dart';
import 'package:loader_overlay/loader_overlay.dart';
import '../../l10n/locale_keys.g.dart';

class HomeController extends GetxController implements GetxService {
  final LMSService lmsService = LMSService.to;
  late final MediaCacheService mediaCache;
  final SharedPreferencesManager parser = Get.find<SharedPreferencesManager>();
  
  // Observable lists
  final RxList<LLMSCourseModel> _topCourses = <LLMSCourseModel>[].obs;
  final RxList<LLMSCourseModel> _newCourses = <LLMSCourseModel>[].obs;
  final RxList<LLMSCourseModel> _wishlistCourses = <LLMSCourseModel>[].obs;
  final RxList<LLMSInstructorModel> _instructors = <LLMSInstructorModel>[].obs;
  final RxList<LLMSCategoryModel> _categories = <LLMSCategoryModel>[].obs;
  
  // Getters
  List<LLMSCourseModel> get topCoursesList => _topCourses;
  List<LLMSCourseModel> get newCoursesList => _newCourses;
  List<LLMSCourseModel> get newCourseList => _newCourses; // Alias for compatibility
  List<LLMSCourseModel> get wishlistCourses => _wishlistCourses;
  List<LLMSInstructorModel> get instructorsList => _instructors;
  List<LLMSInstructorModel> get instructorList => _instructors; // Alias for compatibility
  List<LLMSCategoryModel> get categoriesList => _categories;
  List<LLMSCategoryModel> get cateHomeList => _categories; // Alias for compatibility
  
  // Loading states
  final RxBool isLoadingTopCourses = false.obs;
  final RxBool isLoadingNewCourses = false.obs;
  final RxBool isLoadingInstructors = false.obs;
  final RxBool isLoadingCategories = false.obs;
  final RxBool isNewNotification = false.obs;
  
  // Error states
  final RxString errorMessage = ''.obs;
  final RxBool hasError = false.obs;
  
  // Overview data (for user progress)
  final Rx<dynamic> _overview = Rx<dynamic>(null);
  dynamic get overview => _overview.value;
  
  @override
  void onInit() {
    super.onInit();
    // Initialize media cache service
    if (Get.isRegistered<MediaCacheService>()) {
      mediaCache = Get.find<MediaCacheService>();
    } else {
      // Create a simple cache if service not available
      mediaCache = MediaCacheService();
    }
    loadHomeData();
    if (lmsService.isLoggedIn) {
      loadWishlist();
      // Check user validation in background (non-blocking)
      Future.delayed(const Duration(seconds: 5), () {
        if (lmsService.currentUserId != null) {
          handleCheckoutUser(lmsService.currentUserId.toString());
        }
      });
    }
  }
  
  /// Load all home screen data
  Future<void> loadHomeData() async {
    await Future.wait([
      getTopCourses(),
      getNewCourses(),
      getInstructors(),
      getCategories(),
    ]);
  }
  
  /// Refresh all data
  Future<void> refreshData() async {
    errorMessage.value = '';
    hasError.value = false;
    await loadHomeData();
    if (lmsService.isLoggedIn) {
      await loadWishlist();
    }
  }
  
  /// Load images for courses asynchronously in background
  Future<void> _loadCourseImagesAsync(List<dynamic> coursesData, bool isTopCourses) async {
    final oEmbedFutures = <Future<void>>[];
    final courseList = isTopCourses ? _topCourses : _newCourses;
    
    // Create a map to track which course index corresponds to which media ID
    final courseIndexMap = <int, int>{};
    
    for (int i = 0; i < coursesData.length && i < courseList.length; i++) {
      final courseData = coursesData[i];
      final mediaId = courseData['featured_media'];
      final permalink = courseData['permalink'];
      
      if (mediaId != null && mediaId != 0 && permalink != null && permalink.isNotEmpty) {
        courseIndexMap[mediaId] = i;
        
        // Check cache first
        try {
          final cachedUrl = mediaCache.getCachedUrl(mediaId);
          if (cachedUrl != null && cachedUrl.isNotEmpty && !cachedUrl.contains('undefined')) {
            // Update the specific course with cached image by recreating it
            final updatedCourseData = Map<String, dynamic>.from(courseData);
            updatedCourseData['featured_image_url'] = cachedUrl;
            courseList[i] = LLMSCourseModel.fromJson(updatedCourseData);
            update(); // Update UI for this specific course
            print('Using cached image for media $mediaId');
            continue;
          }
        } catch (e) {
          // Cache miss, fetch from oEmbed
        }
        
        // Fetch via oEmbed
        oEmbedFutures.add(
          lmsService.api.getOEmbedData(courseUrl: permalink)
            .timeout(Duration(seconds: 5)) // Reduce timeout from 30s to 5s
            .then((oEmbedResponse) {
              if (oEmbedResponse.statusCode == 200 && oEmbedResponse.body != null) {
                final thumbnailUrl = oEmbedResponse.body['thumbnail_url'];
                if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
                  // Cache the URL
                  try {
                    mediaCache.cacheUrl(mediaId, thumbnailUrl.toString());
                  } catch (e) {
                    print('Could not cache URL: $e');
                  }
                  print('Got image for course via oEmbed: $thumbnailUrl');
                  
                  // Update the specific course with the image URL
                  final courseIndex = courseIndexMap[mediaId];
                  if (courseIndex != null && courseIndex < courseList.length) {
                    final updatedCourseData = Map<String, dynamic>.from(coursesData[courseIndex]);
                    updatedCourseData['featured_image_url'] = thumbnailUrl.toString();
                    courseList[courseIndex] = LLMSCourseModel.fromJson(updatedCourseData);
                    update(); // Update UI for this specific course
                  }
                }
              }
            }).catchError((e) {
              print('Error fetching oEmbed: $e');
            })
        );
      }
    }
    
    // Process images in batches to avoid overwhelming the server
    if (oEmbedFutures.isNotEmpty) {
      // Process in batches of 3
      for (int i = 0; i < oEmbedFutures.length; i += 3) {
        final end = (i + 3 < oEmbedFutures.length) ? i + 3 : oEmbedFutures.length;
        await Future.wait(oEmbedFutures.sublist(i, end));
      }
    }
  }
  
  /// Get popular/top courses
  Future<void> getTopCourses() async {
    print('getTopCourses() called - current list size: ${_topCourses.length}');
    try {
      isLoadingTopCourses.value = true;
      
      // Using the regular courses endpoint with sorting for popularity
      // Since LifterLMS doesn't have a built-in popular courses endpoint
      final response = await lmsService.api.getCourses(params: {
        'per_page': '10',
        'orderby': 'menu_order', // Or use custom meta field for popularity
        'order': 'asc',
      });
      
      if (response.statusCode == 200) {
        _topCourses.clear();
        if (response.body is List) {
          print('Loading ${response.body.length} top courses');
          
          // Parse courses immediately WITHOUT waiting for images
          for (var courseData in response.body) {
            try {
              final course = LLMSCourseModel.fromJson(courseData);
              _topCourses.add(course);
              print('Successfully loaded course: ${course.title}');
            } catch (e) {
              print('Error parsing course: $e');
            }
          }
          
          // Update UI immediately with courses (no images yet)
          print('Total top courses loaded: ${_topCourses.length}');
          update();
          
          // Load images in background (non-blocking)
          _loadCourseImagesAsync(response.body, true);
        }
      } else {
        _handleError('Failed to load top courses');
      }
    } catch (e) {
      _handleError('Error loading top courses: $e');
    } finally {
      isLoadingTopCourses.value = false;
      update(); // Notify UI to rebuild
    }
  }
  
  /// Get newest courses
  Future<void> getNewCourses() async {
    try {
      isLoadingNewCourses.value = true;
      
      final response = await lmsService.api.getNewCourses(
        page: 1,
        perPage: 10,
      );
      
      if (response.statusCode == 200) {
        _newCourses.clear();
        if (response.body is List) {
          // Parse courses immediately WITHOUT waiting for images
          for (var courseData in response.body) {
            try {
              final course = LLMSCourseModel.fromJson(courseData);
              _newCourses.add(course);
            } catch (e) {
              print('Error parsing course: $e');
            }
          }
          
          // Update UI immediately with courses (no images yet)
          print('Total new courses loaded: ${_newCourses.length}');
          update();
          
          // Load images in background (non-blocking)
          _loadCourseImagesAsync(response.body, false);
        }
      } else {
        _handleError('Failed to load new courses');
      }
    } catch (e) {
      _handleError('Error loading new courses: $e');
    } finally {
      isLoadingNewCourses.value = false;
      update(); // Notify UI to rebuild
    }
  }
  
  /// Get instructors
  Future<void> getInstructors() async {
    try {
      isLoadingInstructors.value = true;
      
      // Use WordPress Users API instead of restricted instructors endpoint
      final response = await lmsService.api.getUsers(params: {
        'per_page': '10',
        'orderby': 'id',
        'order': 'asc',
      });
      
      print('Instructors API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        _instructors.clear();
        if (response.body is List) {
          print('Loading ${response.body.length} instructors');
          // WordPress Users API usually includes avatar_urls directly
          // but let's also handle cases where we might need to fetch media
          for (var instructorData in response.body) {
            try {
              print('Instructor data: avatar_urls=${instructorData['avatar_urls']}, featured_media=${instructorData['featured_media']}');
              
              // Check if there's a featured_media that needs fetching
              if (instructorData['featured_media'] != null && 
                  instructorData['featured_media'] != 0 &&
                  instructorData['avatar_urls'] == null) {
                // Fetch the media URL if needed
                try {
                  final mediaResponse = await lmsService.api.getMedia(
                    mediaId: instructorData['featured_media']
                  );
                  if (mediaResponse.statusCode == 200 && mediaResponse.body != null) {
                    final sourceUrl = mediaResponse.body['source_url'] ?? 
                                     mediaResponse.body['media_details']?['sizes']?['thumbnail']?['source_url'];
                    if (sourceUrl != null) {
                      instructorData['avatar_url'] = sourceUrl;
                    }
                  }
                } catch (e) {
                  print('Error fetching instructor media: $e');
                }
              }
              
              // Create initial instructor model
              var instructor = LLMSInstructorModel.fromJson(instructorData);
              print('Created instructor: ${instructor.displayName} with ID: ${instructor.id}');
              
              // Fetch course count for this instructor
              try {
                final coursesResponse = await lmsService.api.getCourses(params: {
                  'author': instructor.id.toString(),
                  'per_page': '1', // We only need the total count
                });
                
                if (coursesResponse.statusCode == 200) {
                  // Get total count from headers
                  final totalCourses = int.tryParse(
                    coursesResponse.headers?['x-wp-total']?.toString() ?? '0'
                  ) ?? 0;
                  
                  // Update instructor with actual course count
                  instructor = LLMSInstructorModel(
                    id: instructor.id,
                    name: instructor.name,
                    email: instructor.email,
                    username: instructor.username,
                    firstName: instructor.firstName,
                    lastName: instructor.lastName,
                    nickname: instructor.nickname,
                    displayName: instructor.displayName,
                    description: instructor.description,
                    avatarUrl: instructor.avatarUrl,
                    url: instructor.url,
                    link: instructor.link,
                    website: instructor.website,
                    locale: instructor.locale,
                    registeredDate: instructor.registeredDate,
                    roles: instructor.roles,
                    meta: instructor.meta,
                    social: instructor.social,
                    courseCount: totalCourses,
                    studentCount: instructor.studentCount,
                    averageRating: instructor.averageRating,
                    reviewCount: instructor.reviewCount,
                  );
                  print('Instructor ${instructor.displayName} has $totalCourses courses');
                }
              } catch (e) {
                print('Error fetching course count for instructor ${instructor.id}: $e');
              }
              
              _instructors.add(instructor);
              print('Loaded instructor: ${instructor.displayName}, courses: ${instructor.courseCount}');
            } catch (e) {
              print('Error parsing instructor: $e');
            }
          }
          print('Total instructors loaded: ${_instructors.length}');
          
          // Cache all loaded instructors using the existing MediaCacheService
          if (_instructors.isNotEmpty) {
            mediaCache.cacheInstructors(_instructors);
            print('Cached ${_instructors.length} instructors in MediaCacheService');
          }
        }
      } else {
        _handleError('Failed to load instructors');
      }
    } catch (e) {
      _handleError('Error loading instructors: $e');
    } finally {
      isLoadingInstructors.value = false;
    }
  }
  
  /// Get categories
  Future<void> getCategories() async {
    try {
      isLoadingCategories.value = true;
      
      final response = await lmsService.api.getCategories(params: {
        'orderby': 'count',
        'order': 'desc',
        'per_page': '10',
      });
      
      if (response.statusCode == 200) {
        _categories.clear();
        if (response.body is List) {
          for (var categoryData in response.body) {
            try {
              final category = LLMSCategoryModel.fromJson(categoryData);
              _categories.add(category);
            } catch (e) {
              print('Error parsing category: $e');
            }
          }
        }
      } else {
        _handleError('Failed to load categories');
      }
    } catch (e) {
      _handleError('Error loading categories: $e');
    } finally {
      isLoadingCategories.value = false;
    }
  }
  
  /// Load user's wishlist
  Future<void> loadWishlist() async {
    if (!lmsService.isLoggedIn) return;
    
    try {
      final response = await lmsService.getWishlist();
      
      if (response.statusCode == 200) {
        _wishlistCourses.clear();
        if (response.body is List) {
          for (var courseData in response.body) {
            try {
              final course = LLMSCourseModel.fromJson(courseData);
              _wishlistCourses.add(course);
            } catch (e) {
              print('Error parsing wishlist course: $e');
            }
          }
        }
      } else if (response.statusCode == 501) {
        // Wishlist not implemented yet - this is expected
        print('Wishlist feature not yet available');
      }
    } catch (e) {
      print('Error loading wishlist: $e');
    }
  }
  
  /// Toggle wishlist status for a course
  Future<void> toggleWishlist(int courseId) async {
    if (!lmsService.isLoggedIn) {
      Get.toNamed(AppRouter.login);
      return;
    }
    
    try {
      final isInWishlist = _wishlistCourses.any((c) => c.id == courseId);
      
      if (isInWishlist) {
        final response = await lmsService.removeFromWishlist(courseId);
        if (response.statusCode == 200 || response.statusCode == 204) {
          _wishlistCourses.removeWhere((c) => c.id == courseId);
          Get.snackbar(
            'Success',
            'Course removed from wishlist',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      } else {
        final response = await lmsService.addToWishlist(courseId);
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Fetch the course details and add to wishlist
          final courseResponse = await lmsService.api.getCourse(courseId: courseId);
          if (courseResponse.statusCode == 200) {
            final course = LLMSCourseModel.fromJson(courseResponse.body);
            _wishlistCourses.add(course);
            Get.snackbar(
              'Success',
              'Course added to wishlist',
              snackPosition: SnackPosition.BOTTOM,
            );
          }
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update wishlist',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
  
  /// Check if a course is in wishlist
  bool isInWishlist(int courseId) {
    return _wishlistCourses.any((c) => c.id == courseId);
  }
  
  /// Navigate to course detail
  void goToCourseDetail(int courseId) {
    Get.toNamed(
      AppRouter.getCourseDetail(),
      arguments: {'id': courseId},
    );
  }
  
  /// Navigate to instructor detail
  void goToInstructorDetail(int instructorId) {
    Get.toNamed(
      AppRouter.getInstructorDetail(),
      arguments: {'id': instructorId},
    );
  }
  
  /// Navigate to category courses
  void goToCategoryDetail(int categoryId, String categoryName) {
    Get.toNamed(
      AppRouter.getCoursesByCategory(),
      arguments: {
        'id': categoryId,
        'name': categoryName,
      },
    );
  }
  
  /// Update notification status
  void updateShowNotification(String status) {
    isNewNotification.value = status == 'true';
  }
  
  /// Get overview data (user progress summary)
  Future<void> getOverview() async {
    try {
      if (lmsService.isLoggedIn) {
        // TODO: Implement overview API call for LifterLMS
        // This would fetch user's learning progress summary
        _overview.value = {
          'id': lmsService.currentUser?['id'] ?? 0,
          'courses_enrolled': 0,
          'courses_completed': 0,
          'lessons_completed': 0,
        };
      }
    } catch (e) {
      print('Error loading overview: $e');
    }
  }
  
  /// Handle checkout user (check if user still exists/is valid)
  Future<void> handleCheckoutUser(String userId) async {
    try {
      // TODO: Implement user validation check
      // This would verify if the user account is still valid
      print('Checking user status: $userId');
    } catch (e) {
      print('Error checking user: $e');
    }
  }
  
  /// Toggle wishlist for a course (compatibility method)
  Future<void> onToggleWishlist(LLMSCourseModel course) async {
    await toggleWishlist(course.id);
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
  
  /// Set overview ID (for compatibility)
  void setOverviewId(String id) {
    // This is for LearnPress compatibility
    // LifterLMS doesn't need this functionality
  }
  
  /// Get home data (main data loading method)
  Future<void> getHomeData() async {
    await loadHomeData();
  }
  
  /// Get home content (alias for getHomeData)
  Future<void> getHomeContent() async {
    await loadHomeData();
  }
  
  /// Refresh screen data
  Future<void> refreshScreen() async {
    await loadHomeData();
  }
}