import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/backend/services/media_cache_service.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:get/get.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../l10n/locale_keys.g.dart';

class CoursesController extends GetxController implements GetxService {
  final LMSService lmsService = LMSService.to;
  final MediaCacheService mediaCache = Get.find<MediaCacheService>();
  
  // Observable lists
  final RxList<LLMSCourseModel> _courses = <LLMSCourseModel>[].obs;
  final RxList<dynamic> _categories = <dynamic>[].obs;
  
  // Getters
  List<LLMSCourseModel> get coursesList => _courses;
  List<dynamic> get categoriesList => _categories;
  
  // Pagination
  final RxInt currentPage = 1.obs;
  final RxInt totalPages = 1.obs;
  final RxInt totalCourses = 0.obs;
  final RxBool hasMoreData = true.obs;
  final int perPage = 10;
  
  // Loading states
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isLoadingCategories = false.obs;
  
  // Filters
  final RxString selectedCategory = ''.obs;
  final RxInt selectedCategoryId = 0.obs;
  final RxString searchQuery = ''.obs;
  final RxString sortBy = 'date_created'.obs; // date_created, date_updated, title, menu_order
  final RxString sortOrder = 'desc'.obs; // asc, desc
  final RxString priceFilter = 'all'.obs; // all, free, paid
  
  // For LearnPress view compatibility
  final RxList<int> cateIds = <int>[].obs; // Selected category IDs for filtering
  
  // Error handling
  final RxString errorMessage = ''.obs;
  final RxBool hasError = false.obs;
  
  // Scroll controller for infinite scrolling
  ScrollController scrollController = ScrollController();
  
  @override
  void onInit() {
    super.onInit();
    initializeScrollListener();
    loadInitialData();
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
          loadMoreCourses();
        }
      }
    });
  }
  
  /// Load initial data
  Future<void> loadInitialData() async {
    await Future.wait([
      getCourses(),
      getCategories(),
    ]);
  }
  
  /// Get courses with filters
  Future<void> getCourses({bool isRefresh = false}) async {
    if (isRefresh) {
      currentPage.value = 1;
      hasMoreData.value = true;
    }
    
    try {
      isLoading.value = true;
      errorMessage.value = '';
      hasError.value = false;
      
      // Build query parameters
      final params = <String, dynamic>{
        'page': currentPage.value.toString(),
        'per_page': perPage.toString(),
        'orderby': sortBy.value,
        'order': sortOrder.value,
        '_embed': '',  // Include embedded resources like featured media
      };
      
      // Add category filter
      if (selectedCategoryId.value > 0) {
        params['categories'] = selectedCategoryId.value.toString();
      }
      
      // Add search query
      if (searchQuery.value.isNotEmpty) {
        params['search'] = searchQuery.value;
      }
      
      // Add price filter
      if (priceFilter.value == 'free') {
        params['price_type'] = 'free';
      } else if (priceFilter.value == 'paid') {
        params['price_type'] = 'paid';
      }
      
      final response = await lmsService.api.getCourses(params: params);
      
      print('Courses API response status: ${response.statusCode}');
      print('Courses API response body type: ${response.body.runtimeType}');
      
      if (response.statusCode == 200) {
        if (isRefresh) {
          _courses.clear();
        }
        
        if (response.body is List) {
          // First, check if any courses need media fetching
          // Only fetch if the _embedded data doesn't already contain the media
          final mediaIds = <int>{};
          for (var courseData in response.body) {
            // Check if embedded media is already available
            if (courseData['_embedded']?['wp:featuredmedia'] == null) {
              final mediaId = courseData['featured_media'];
              if (mediaId != null && mediaId != 0) {
                mediaIds.add(mediaId);
              }
            }
          }
          
          // Fetch images using oEmbed (no auth required, faster!)
          final mediaUrls = <int, String>{};
          final oEmbedFutures = <Future<void>>[];
          
          if (mediaIds.isNotEmpty) {
            print('Fetching ${mediaIds.length} media items via oEmbed');
            
            for (var courseData in response.body) {
              final mediaId = courseData['featured_media'];
              final permalink = courseData['permalink'];
              
              if (mediaId != null && mediaId != 0 && mediaIds.contains(mediaId)) {
                // Check cache first
                final cachedUrl = mediaCache.getCachedUrl(mediaId);
                if (cachedUrl != null) {
                  mediaUrls[mediaId] = cachedUrl;
                  print('Using cached image for media $mediaId');
                } else if (permalink != null && permalink.isNotEmpty) {
                  // Fetch via oEmbed
                  oEmbedFutures.add(
                    lmsService.api.getOEmbedData(courseUrl: permalink).then((oEmbedResponse) {
                      if (oEmbedResponse.statusCode == 200 && oEmbedResponse.body != null) {
                        final thumbnailUrl = oEmbedResponse.body['thumbnail_url'];
                        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
                          mediaUrls[mediaId] = thumbnailUrl;
                          // Cache the URL
                          try {
                            mediaCache.cacheUrl(mediaId, thumbnailUrl);
                          } catch (e) {
                            print('Could not cache URL: $e');
                          }
                          print('Got image via oEmbed: $thumbnailUrl');
                        }
                      }
                    }).catchError((e) {
                      print('Error fetching oEmbed for $permalink: $e');
                    })
                  );
                }
              }
            }
            
            if (oEmbedFutures.isNotEmpty) {
              await Future.wait(oEmbedFutures);
              print('All oEmbed fetches complete');
            }
          } else {
            print('Using embedded media data (no separate fetches needed)');
          }
          
          // Now parse courses
          for (var courseData in response.body) {
            try {
              // Only add manually fetched URL if we had to fetch it
              if (mediaUrls.isNotEmpty) {
                final mediaId = courseData['featured_media'];
                if (mediaId != null && mediaUrls.containsKey(mediaId)) {
                  courseData['featured_image_url'] = mediaUrls[mediaId];
                }
              }
              
              final course = LLMSCourseModel.fromJson(courseData);
              _courses.add(course);
            } catch (e) {
              print('Error parsing course: $e');
            }
          }
          
          // Check if there's more data
          if ((response.body as List).length < perPage) {
            hasMoreData.value = false;
          }
          
          // Update total from headers if available
          final totalHeader = response.headers?['X-WP-Total'];
          if (totalHeader != null) {
            totalCourses.value = int.tryParse(totalHeader) ?? 0;
            totalPages.value = response.headers?['X-WP-TotalPages'] != null
                ? int.tryParse(response.headers!['X-WP-TotalPages'] ?? '') ?? 1
                : 1;
          }
          update(); // Notify UI to rebuild
        }
      } else {
        print('Failed to load courses. Status: ${response.statusCode}, Body: ${response.body}');
        _handleError('Failed to load courses: Status ${response.statusCode}');
      }
    } catch (e, stack) {
      print('Error loading courses: $e\nStack: $stack');
      _handleError('Error loading courses: $e');
    } finally {
      isLoading.value = false;
      update(); // Notify UI to rebuild
    }
  }
  
  /// Load more courses (pagination)
  Future<void> loadMoreCourses() async {
    if (isLoadingMore.value || !hasMoreData.value) return;
    
    try {
      isLoadingMore.value = true;
      currentPage.value++;
      
      await getCourses();
    } finally {
      isLoadingMore.value = false;
    }
  }
  
  /// Get categories
  Future<void> getCategories() async {
    try {
      isLoadingCategories.value = true;
      
      final response = await lmsService.api.getCategories(params: {
        'orderby': 'count',
        'order': 'desc',
        'hide_empty': 'true',
      });
      
      if (response.statusCode == 200) {
        _categories.clear();
        if (response.body is List) {
          _categories.addAll(response.body);
        }
      }
    } catch (e) {
      print('Error loading categories: $e');
    } finally {
      isLoadingCategories.value = false;
    }
  }
  
  /// Apply category filter
  void filterByCategory(int categoryId, String categoryName) {
    if (selectedCategoryId.value == categoryId) {
      // Clear filter if same category selected
      selectedCategoryId.value = 0;
      selectedCategory.value = '';
    } else {
      selectedCategoryId.value = categoryId;
      selectedCategory.value = categoryName;
    }
    refreshCourses();
  }
  
  /// Apply search
  void searchCourses(String query) {
    searchQuery.value = query;
    refreshCourses();
  }
  
  /// Apply sorting
  void setSorting(String sort, String order) {
    sortBy.value = sort;
    sortOrder.value = order;
    refreshCourses();
  }
  
  /// Apply price filter
  void setPriceFilter(String filter) {
    priceFilter.value = filter;
    refreshCourses();
  }
  
  /// Clear all filters
  void clearFilters() {
    selectedCategoryId.value = 0;
    selectedCategory.value = '';
    searchQuery.value = '';
    sortBy.value = 'date';
    sortOrder.value = 'desc';
    priceFilter.value = 'all';
    refreshCourses();
  }
  
  /// Refresh courses list
  Future<void> refreshCourses() async {
    currentPage.value = 1;
    hasMoreData.value = true;
    _courses.clear();
    await getCourses(isRefresh: true);
  }
  
  /// Navigate to course detail
  void goToCourseDetail(int courseId) {
    Get.toNamed(
      AppRouter.getCourseDetail(),
      arguments: {'id': courseId},
    );
  }
  
  /// Enroll in course
  Future<void> enrollInCourse(int courseId) async {
    if (!lmsService.isLoggedIn) {
      Get.toNamed(AppRouter.login);
      return;
    }
    
    try {
      Get.dialog(
        Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );
      
      final response = await lmsService.enrollInCourse(courseId);
      
      Get.back(); // Close loading dialog
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        Get.snackbar(
          'Success',
          'Successfully enrolled in course',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        
        // Navigate to course learning page
        Get.toNamed(
          AppRouter.getLearning(),
          arguments: {'id': courseId},
        );
      } else if (response.statusCode == 400) {
        // Already enrolled
        Get.snackbar(
          'Info',
          'You are already enrolled in this course',
          snackPosition: SnackPosition.BOTTOM,
        );
        
        // Navigate to course learning page
        Get.toNamed(
          AppRouter.getLearning(),
          arguments: {'id': courseId},
        );
      } else {
        Get.snackbar(
          'Error',
          response.statusText ?? 'Failed to enroll in course',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.back(); // Close loading dialog if still open
      Get.snackbar(
        'Error',
        'An error occurred while enrolling',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
  
  /// Check if user is enrolled in course
  Future<bool> isEnrolled(int courseId) async {
    if (!lmsService.isLoggedIn) return false;
    
    try {
      final response = await lmsService.api.getEnrollmentStatus(
        userId: lmsService.currentUserId!,
        courseId: courseId,
      );
      
      if (response.statusCode == 200) {
        final status = response.body['status'];
        return status == 'enrolled';
      }
    } catch (e) {
      print('Error checking enrollment: $e');
    }
    
    return false;
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
  
  /// Refresh screen data (for compatibility)
  Future<void> refreshScreen() async {
    await getCourses();
  }
  
  // ===== Methods for LearnPress view compatibility =====
  
  /// Handle getting filter options (for compatibility with old views)
  /// This fetches categories which are used as filter options
  void handleGetOption() {
    getCategories();
  }
  
  /// Filter courses by multiple category IDs (for compatibility with old views)
  /// This method is called by the categories_course.dart view
  void onFilter(List<int> categoryIds) {
    cateIds.value = categoryIds;
    
    // LifterLMS API typically handles one category at a time via query params
    // For multiple categories, we'd need to make multiple requests or use the first one
    if (categoryIds.isNotEmpty) {
      // Use the first category ID for now (LifterLMS limitation)
      selectedCategoryId.value = categoryIds.first;
      
      // Find category name if available
      final category = _categories.firstWhereOrNull(
        (cat) => cat['id'] == categoryIds.first
      );
      if (category != null) {
        selectedCategory.value = category['name'] ?? '';
      }
    } else {
      // Clear filter
      selectedCategoryId.value = 0;
      selectedCategory.value = '';
    }
    
    // Refresh courses with new filter
    refreshCourses();
  }
}