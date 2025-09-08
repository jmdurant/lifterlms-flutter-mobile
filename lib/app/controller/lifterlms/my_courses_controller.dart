import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/backend/services/media_cache_service.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/util/toast.dart';
import 'package:get/get.dart';

class MyCoursesController extends GetxController {
  final LMSService lmsService = LMSService.to;
  final MediaCacheService mediaCache = Get.find<MediaCacheService>();
  
  // Observable lists for different course states
  final RxList<LLMSCourseModel> _allCourses = <LLMSCourseModel>[].obs;
  final RxList<LLMSCourseModel> _inProgressCourses = <LLMSCourseModel>[].obs;
  final RxList<LLMSCourseModel> _completedCourses = <LLMSCourseModel>[].obs;
  final RxList<LLMSCourseModel> _notStartedCourses = <LLMSCourseModel>[].obs;
  
  // Getters
  List<LLMSCourseModel> get allCourses => _allCourses;
  List<LLMSCourseModel> get inProgressCourses => _inProgressCourses;
  List<LLMSCourseModel> get completedCourses => _completedCourses;
  List<LLMSCourseModel> get notStartedCourses => _notStartedCourses;
  
  // Progress data for each course
  final RxMap<int, double> courseProgress = <int, double>{}.obs;
  final RxMap<int, Map<String, dynamic>> enrollmentData = <int, Map<String, dynamic>>{}.obs;
  
  // Tab selection
  final RxInt selectedTab = 1.obs; // Default to "In Progress"
  
  // Loading states
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  
  // Pagination
  final RxInt currentPage = 1.obs;
  final RxBool hasMoreData = true.obs;
  final int perPage = 30;
  
  // Filter and sort
  final RxString sortBy = 'date_enrolled'.obs; // date_enrolled, progress, title
  final RxString sortOrder = 'desc'.obs; // asc, desc
  final RxString filterStatus = 'all'.obs; // all, in_progress, completed, not_started
  
  // Error handling
  final RxString errorMessage = ''.obs;
  final RxBool hasError = false.obs;
  
  // Scroll controller
  ScrollController scrollController = ScrollController();
  
  // Cache management
  DateTime? _lastFetchTime;
  final Duration _cacheExpiry = const Duration(minutes: 5);
  bool _isInitialLoad = true;
  
  @override
  void onInit() {
    super.onInit();
    initializeScrollListener();
    // Don't auto-load on init, let the view trigger it
  }
  
  /// Called when tab becomes visible
  void onTabVisible() {
    if (lmsService.isLoggedIn) {
      // If we have data and it's fresh, don't reload
      if (_allCourses.isNotEmpty && 
          _lastFetchTime != null && 
          DateTime.now().difference(_lastFetchTime!) < _cacheExpiry) {
        print('MyCoursesController - Tab visible, using cached data');
        return;
      }
      // Otherwise load with cache check
      loadMyCoursesWithCache();
    }
  }
  
  /// Load courses with cache check
  Future<void> loadMyCoursesWithCache({bool forceRefresh = false}) async {
    // Check if we should use cached data
    if (!forceRefresh && 
        _lastFetchTime != null && 
        _allCourses.isNotEmpty &&
        DateTime.now().difference(_lastFetchTime!) < _cacheExpiry) {
      print('MyCoursesController - Using cached courses data');
      // Data is still fresh, just re-categorize in case of state changes
      _categorizeCourses();
      return;
    }
    
    // If we have cached data and it's not a force refresh, show cached data immediately
    // and refresh in background
    if (_allCourses.isNotEmpty && !forceRefresh) {
      print('MyCoursesController - Showing cached data, refreshing in background');
      // Don't show loading spinner, just refresh in background
      _loadInBackground();
    } else {
      // Only show loading spinner for initial load or forced refresh when no cache exists
      await loadMyCourses(isRefresh: forceRefresh);
      _lastFetchTime = DateTime.now();
      _isInitialLoad = false;
    }
  }
  
  /// Load data in background without showing loading indicator
  Future<void> _loadInBackground() async {
    print('MyCoursesController - Refreshing data in background');
    try {
      // Don't set isLoading to avoid showing spinner
      final response = await lmsService.getMyEnrollments(params: {
        'page': '1',
        'per_page': '30',
        'status': 'enrolled',
      });
      
      if (response.statusCode == 200 && response.body is List) {
        // Process new data without clearing existing display
        await _processEnrollmentsInBackground(response.body as List);
        _lastFetchTime = DateTime.now();
      }
    } catch (e) {
      print('Background refresh failed: $e');
      // Don't show error for background refresh
    }
  }
  
  /// Process enrollments in background without clearing current display
  Future<void> _processEnrollmentsInBackground(List enrollments) async {
    // Similar to regular processing but doesn't clear lists first
    List<Map<String, dynamic>> validEnrollments = [];
    
    for (var enrollment in enrollments) {
      final courseId = enrollment['post_id'] ?? enrollment['course_id'];
      if (courseId != null) {
        validEnrollments.add(enrollment);
        enrollmentData[courseId] = enrollment;
      }
    }
    
    // Process in batches
    const batchSize = 10;
    for (int i = 0; i < validEnrollments.length; i += batchSize) {
      final batch = validEnrollments.skip(i).take(batchSize).toList();
      List<Future> batchFutures = [];
      
      for (var enrollment in batch) {
        final courseId = enrollment['post_id'];
        batchFutures.add(_fetchCourseWithProgress(courseId, enrollment));
      }
      
      await Future.wait(batchFutures, eagerError: false);
    }
    
    // Update categories after all data is loaded
    _categorizeCourses();
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
  
  /// Load user's enrolled courses
  Future<void> loadMyCourses({bool isRefresh = false}) async {
    if (!lmsService.isLoggedIn) {
      _handleError('Please login to view your courses');
      return;
    }
    
    if (isRefresh) {
      currentPage.value = 1;
      hasMoreData.value = true;
      _clearAllLists();
    }
    
    try {
      isLoading.value = true;
      errorMessage.value = '';
      hasError.value = false;
      
      // Get user's enrollments
      final response = await lmsService.getMyEnrollments(params: {
        'page': currentPage.value.toString(),
        'per_page': '30', // Get more per page to reduce API calls
        'status': 'enrolled', // Only get active enrollments
      });
      
      if (response.statusCode == 200) {
        if (response.body is List) {
          final enrollments = response.body as List;
          print('MyCoursesController - Got ${enrollments.length} enrollments');
          
          // Group enrollments for batch processing
          List<Map<String, dynamic>> validEnrollments = [];
          
          for (var enrollment in enrollments) {
            final courseId = enrollment['post_id'] ?? enrollment['course_id'];
            if (courseId != null) {
              validEnrollments.add(enrollment);
              // Store enrollment data immediately
              enrollmentData[courseId] = enrollment;
            }
          }
          
          // Process in batches of 10 for better performance
          const batchSize = 10;
          for (int i = 0; i < validEnrollments.length; i += batchSize) {
            final batch = validEnrollments.skip(i).take(batchSize).toList();
            
            // Create parallel futures for this batch
            List<Future> batchFutures = [];
            
            for (var enrollment in batch) {
              final courseId = enrollment['post_id'];
              
              // Fetch course details
              batchFutures.add(_fetchCourseWithProgress(courseId, enrollment));
            }
            
            // Wait for this batch to complete
            await Future.wait(batchFutures, eagerError: false);
            
            // Update UI after each batch for progressive loading
            _categorizeCourses();
          }
          
          // Check if there's more data
          if (enrollments.length < 30) {
            hasMoreData.value = false;
          }
        }
        
        // Final categorization
        _categorizeCourses();
      } else {
        _handleError('Failed to load your courses');
      }
    } catch (e) {
      _handleError('Error loading courses: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Fetch course with progress data
  Future<void> _fetchCourseWithProgress(int courseId, Map<String, dynamic> enrollment) async {
    try {
      // First, just fetch the course
      final courseResponse = await lmsService.api.getCourse(courseId: courseId);
      
      // Handle course response
      if (courseResponse.statusCode == 404) {
        print('MyCoursesController - Course $courseId does not exist (deleted or invalid enrollment)');
        return;
      } else if (courseResponse.statusCode != 200) {
        print('MyCoursesController - Failed to load course $courseId: ${courseResponse.statusCode}');
        return;
      }
      
      var courseData = courseResponse.body;
      
      // Set initial progress based on enrollment status
      final status = enrollment['status'] ?? 'enrolled';
      if (status == 'completed') {
        courseProgress[courseId] = 100.0;
      } else {
        // Don't assume 0, let progress API tell us
        courseProgress[courseId] = courseProgress[courseId] ?? 0.0;
      }
      
      // Fetch actual progress from API (wait for it to ensure correct categorization)
      final progressResponse = await lmsService.getCourseProgress(courseId);
      if (progressResponse.statusCode == 200 && progressResponse.body != null) {
        final progressData = progressResponse.body;
        final progress = (progressData['progress'] ?? 0).toDouble();
        courseProgress[courseId] = progress;
        print('MyCoursesController - Course $courseId progress: $progress%');
      }
      
      // Fetch featured image if needed
      if (courseData['featured_media'] != null && courseData['featured_media'] != 0) {
        final mediaId = courseData['featured_media'];
        final permalink = courseData['permalink'];
        
        // Check cache first
        final cachedUrl = mediaCache.getCachedUrl(mediaId);
        if (cachedUrl != null) {
          courseData['featured_image_url'] = cachedUrl;
          print('MyCoursesController - Using cached image for media $mediaId');
        } else if (permalink != null && permalink.isNotEmpty) {
          // Fetch via oEmbed in background (don't wait)
          _fetchOEmbedImage(courseId, mediaId, permalink);
        }
      }
      
      final course = LLMSCourseModel.fromJson(courseData);
      
      // Add to all courses list
      if (!_allCourses.any((c) => c.id == course.id)) {
        _allCourses.add(course);
      }
    } catch (e) {
      print('Error fetching course $courseId: $e');
    }
  }
  
  /// Fetch oEmbed image in background
  Future<void> _fetchOEmbedImage(int courseId, int mediaId, String permalink) async {
    try {
      final oEmbedResponse = await lmsService.api.getOEmbedData(courseUrl: permalink);
      
      if (oEmbedResponse.statusCode == 200 && oEmbedResponse.body != null) {
        final thumbnailUrl = oEmbedResponse.body['thumbnail_url'];
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
          // Cache the URL
          mediaCache.cacheUrl(mediaId, thumbnailUrl);
          
          // Update course if it exists
          final courseIndex = _allCourses.indexWhere((c) => c.id == courseId);
          if (courseIndex != -1) {
            // Trigger UI update by reassigning
            final course = _allCourses[courseIndex];
            _allCourses[courseIndex] = course;
            print('MyCoursesController - Updated image for course $courseId');
          }
        }
      }
    } catch (e) {
      print('Error fetching oEmbed for course $courseId: $e');
    }
  }
  
  /// Process enrollment data (legacy method for compatibility)
  Future<void> _processEnrollment(Map<String, dynamic> enrollment) async {
    try {
      final courseId = enrollment['post_id'] ?? enrollment['course_id'];
      if (courseId == null) return;
      
      // Store enrollment data including status
      enrollmentData[courseId] = enrollment;
      
      // Extract enrollment status for categorization
      final enrollmentStatus = enrollment['status'] ?? 'enrolled';
      
      // Store enrollment status for categorization (don't fake progress)
      if (enrollmentStatus == 'completed') {
        courseProgress[courseId] = 100.0;
      } else {
        // Don't set fake progress - will fetch real progress if needed
        courseProgress[courseId] = 0.0;
      }
      
      var courseData;
      
      // Check if course data is embedded in the enrollment response
      if (enrollment['_embedded'] != null) {
        // Check for course first, then membership
        if (enrollment['_embedded']['course'] != null &&
            enrollment['_embedded']['course'].isNotEmpty) {
          courseData = enrollment['_embedded']['course'][0];
          print('MyCoursesController - Using embedded course data for course $courseId');
        } else if (enrollment['_embedded']['membership'] != null &&
                   enrollment['_embedded']['membership'].isNotEmpty) {
          // This is a membership, not a course - skip it
          print('MyCoursesController - Skipping membership enrollment: $courseId');
          return;
        }
      } 
      
      if (courseData == null) {
        // Fallback to fetching course details separately
        final courseResponse = await lmsService.api.getCourse(courseId: courseId);
        
        if (courseResponse.statusCode == 404) {
          print('MyCoursesController - Course $courseId does not exist (deleted or invalid enrollment)');
          return;
        } else if (courseResponse.statusCode != 200) {
          print('MyCoursesController - Failed to load course $courseId: ${courseResponse.statusCode}');
          return;
        }
        courseData = courseResponse.body;
      }
      
      if (courseData != null) {
        
        // Fetch featured image using oEmbed if needed
        if (courseData['featured_media'] != null && courseData['featured_media'] != 0) {
          final mediaId = courseData['featured_media'];
          final permalink = courseData['permalink'];
          
          // Check cache first
          final cachedUrl = mediaCache.getCachedUrl(mediaId);
          if (cachedUrl != null) {
            courseData['featured_image_url'] = cachedUrl;
            print('MyCoursesController - Using cached image for media $mediaId');
          } else if (permalink != null && permalink.isNotEmpty) {
            // Fetch via oEmbed
            try {
              final oEmbedResponse = await lmsService.api.getOEmbedData(courseUrl: permalink);
              
              if (oEmbedResponse.statusCode == 200 && oEmbedResponse.body != null) {
                final thumbnailUrl = oEmbedResponse.body['thumbnail_url'];
                if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
                  courseData['featured_image_url'] = thumbnailUrl;
                  // Cache the URL
                  mediaCache.cacheUrl(mediaId, thumbnailUrl);
                  print('MyCoursesController - Got image via oEmbed: $thumbnailUrl');
                }
              }
            } catch (e) {
              print('Error fetching oEmbed for course $courseId: $e');
            }
          }
        }
        
        final course = LLMSCourseModel.fromJson(courseData);
        
        // Progress is already set from enrollment status above
        // Only fetch detailed progress if needed for specific status
        if (enrollmentStatus == 'enrolled' || enrollmentStatus == 'incomplete') {
          // Optional: fetch actual progress percentage for in-progress courses
          // await _getCourseProgress(course.id);
        }
        
        // Add to all courses list
        if (!_allCourses.any((c) => c.id == course.id)) {
          _allCourses.add(course);
        }
      }
    } catch (e) {
      print('Error processing enrollment: $e');
    }
  }
  
  /// Get progress for a specific course (now integrated into fetch)
  Future<void> _getCourseProgress(int courseId) async {
    try {
      final response = await lmsService.getCourseProgress(courseId);
      
      if (response.statusCode == 200 && response.body != null) {
        final progressData = response.body;
        final progress = (progressData['progress'] ?? 0).toDouble();
        courseProgress[courseId] = progress;
        print('MyCoursesController - Updated progress for course $courseId: $progress%');
      }
    } catch (e) {
      print('Error getting course progress: $e');
      courseProgress[courseId] = 0.0;
    }
  }
  
  /// Categorize courses based on progress percentage
  void _categorizeCourses() {
    _inProgressCourses.clear();
    _completedCourses.clear();
    _notStartedCourses.clear();
    
    for (var course in _allCourses) {
      final progress = courseProgress[course.id] ?? 0.0;
      
      if (progress >= 100) {
        _completedCourses.add(course);
      } else if (progress > 0) {
        _inProgressCourses.add(course);
      } else {
        _notStartedCourses.add(course);
      }
    }
    
    // Apply sorting
    _sortCourses();
  }
  
  /// Sort courses based on selected criteria
  void _sortCourses() {
    // Always sort by progress first (in-progress courses at top)
    _sortByProgressAndDate();
    
    // Then apply additional sorting within each category
    final isAsc = sortOrder.value == 'asc';
    
    switch (sortBy.value) {
      case 'progress':
        _sortByProgress(isAsc);
        break;
      case 'title':
        _sortByTitle(isAsc);
        break;
      case 'date_enrolled':
      default:
        _sortByEnrollmentDate(isAsc);
        break;
    }
  }
  
  /// Sort by progress and date - prioritize in-progress, then by date
  void _sortByProgressAndDate() {
    // Sort all courses
    _allCourses.sort((a, b) {
      final progressA = courseProgress[a.id] ?? 0.0;
      final progressB = courseProgress[b.id] ?? 0.0;
      
      // First priority: In-progress courses (0 < progress < 100)
      final aInProgress = progressA > 0 && progressA < 100;
      final bInProgress = progressB > 0 && progressB < 100;
      
      if (aInProgress && !bInProgress) return -1;
      if (!aInProgress && bInProgress) return 1;
      
      // If both are in same category, sort by enrollment date (newest first)
      final dateA = enrollmentData[a.id]?['date_updated'] ?? enrollmentData[a.id]?['date_created'] ?? '';
      final dateB = enrollmentData[b.id]?['date_updated'] ?? enrollmentData[b.id]?['date_created'] ?? '';
      return dateB.compareTo(dateA);
    });
    
    // Sort category lists
    _inProgressCourses.sort((a, b) {
      final progressA = courseProgress[a.id] ?? 0.0;
      final progressB = courseProgress[b.id] ?? 0.0;
      // Higher progress first for in-progress courses
      return progressB.compareTo(progressA);
    });
    
    _completedCourses.sort((a, b) {
      // Sort by completion date (use date_updated)
      final dateA = enrollmentData[a.id]?['date_updated'] ?? '';
      final dateB = enrollmentData[b.id]?['date_updated'] ?? '';
      return dateB.compareTo(dateA);
    });
    
    _notStartedCourses.sort((a, b) {
      // Sort by enrollment date
      final dateA = enrollmentData[a.id]?['date_created'] ?? '';
      final dateB = enrollmentData[b.id]?['date_created'] ?? '';
      return dateB.compareTo(dateA);
    });
  }
  
  /// Sort by progress
  void _sortByProgress(bool ascending) {
    _allCourses.sort((a, b) {
      final progressA = courseProgress[a.id] ?? 0.0;
      final progressB = courseProgress[b.id] ?? 0.0;
      return ascending 
          ? progressA.compareTo(progressB)
          : progressB.compareTo(progressA);
    });
  }
  
  /// Sort by title
  void _sortByTitle(bool ascending) {
    _allCourses.sort((a, b) {
      return ascending
          ? a.title.compareTo(b.title)
          : b.title.compareTo(a.title);
    });
  }
  
  /// Sort by enrollment date
  void _sortByEnrollmentDate(bool ascending) {
    _allCourses.sort((a, b) {
      final dateA = enrollmentData[a.id]?['date_created'] ?? '';
      final dateB = enrollmentData[b.id]?['date_created'] ?? '';
      return ascending
          ? dateA.compareTo(dateB)
          : dateB.compareTo(dateA);
    });
  }
  
  /// Load more courses (pagination)
  Future<void> loadMoreCourses() async {
    if (isLoadingMore.value || !hasMoreData.value || isLoading.value) return;
    
    try {
      isLoadingMore.value = true;
      currentPage.value++;
      
      // Get next page of enrollments
      final response = await lmsService.getMyEnrollments(params: {
        'page': currentPage.value.toString(),
        'per_page': '30',
        'status': 'enrolled',
      });
      
      if (response.statusCode == 200 && response.body is List) {
        final enrollments = response.body as List;
        print('MyCoursesController - Loading page ${currentPage.value}, got ${enrollments.length} more enrollments');
        
        if (enrollments.isEmpty) {
          hasMoreData.value = false;
          return;
        }
        
        // Process new enrollments
        List<Map<String, dynamic>> validEnrollments = [];
        
        for (var enrollment in enrollments) {
          final courseId = enrollment['post_id'] ?? enrollment['course_id'];
          if (courseId != null) {
            validEnrollments.add(enrollment);
            enrollmentData[courseId] = enrollment;
          }
        }
        
        // Process in batches
        const batchSize = 10;
        for (int i = 0; i < validEnrollments.length; i += batchSize) {
          final batch = validEnrollments.skip(i).take(batchSize).toList();
          
          List<Future> batchFutures = [];
          for (var enrollment in batch) {
            final courseId = enrollment['post_id'];
            batchFutures.add(_fetchCourseWithProgress(courseId, enrollment));
          }
          
          await Future.wait(batchFutures, eagerError: false);
          _categorizeCourses();
        }
        
        // Check if there's more data
        if (enrollments.length < 30) {
          hasMoreData.value = false;
        }
      }
    } catch (e) {
      print('Error loading more courses: $e');
      currentPage.value--; // Revert page on error
    } finally {
      isLoadingMore.value = false;
    }
  }
  
  /// Refresh data (pull to refresh)
  Future<void> refreshData() async {
    print('MyCoursesController - Pull to refresh triggered');
    // Don't clear existing data, just fetch new data
    await _refreshInBackground();
    _lastFetchTime = DateTime.now();
  }
  
  /// Refresh without clearing current display
  Future<void> _refreshInBackground() async {
    try {
      currentPage.value = 1;
      hasMoreData.value = true;
      
      final response = await lmsService.getMyEnrollments(params: {
        'page': '1',
        'per_page': '30',
        'status': 'enrolled',
      });
      
      if (response.statusCode == 200 && response.body is List) {
        final enrollments = response.body as List;
        
        // Build new lists without clearing current display
        final newCourses = <LLMSCourseModel>[];
        final newEnrollmentData = <int, Map<String, dynamic>>{};
        final newCourseProgress = <int, double>{};
        
        // Process new enrollments
        List<Map<String, dynamic>> validEnrollments = [];
        
        for (var enrollment in enrollments) {
          final courseId = enrollment['post_id'] ?? enrollment['course_id'];
          if (courseId != null) {
            validEnrollments.add(enrollment);
            newEnrollmentData[courseId] = enrollment;
          }
        }
        
        // Process in batches
        const batchSize = 10;
        for (int i = 0; i < validEnrollments.length; i += batchSize) {
          final batch = validEnrollments.skip(i).take(batchSize).toList();
          List<Future> batchFutures = [];
          
          for (var enrollment in batch) {
            final courseId = enrollment['post_id'];
            batchFutures.add(_fetchCourseForRefresh(
              courseId, 
              enrollment, 
              newCourses, 
              newCourseProgress
            ));
          }
          
          await Future.wait(batchFutures, eagerError: false);
        }
        
        // Only update the lists after all data is fetched
        _allCourses.clear();
        _allCourses.addAll(newCourses);
        enrollmentData.clear();
        enrollmentData.addAll(newEnrollmentData);
        courseProgress.clear();
        courseProgress.addAll(newCourseProgress);
        
        // Update categories
        _categorizeCourses();
        
        if (enrollments.length < 30) {
          hasMoreData.value = false;
        }
      }
    } catch (e) {
      print('Refresh failed: $e');
      // Don't show error on refresh - keep existing data
    }
  }
  
  /// Fetch course for refresh (builds new list)
  Future<void> _fetchCourseForRefresh(
    int courseId, 
    Map<String, dynamic> enrollment,
    List<LLMSCourseModel> newCourses,
    Map<int, double> newCourseProgress,
  ) async {
    try {
      final courseResponse = await lmsService.api.getCourse(courseId: courseId);
      
      if (courseResponse.statusCode == 404) {
        return; // Skip deleted courses
      } else if (courseResponse.statusCode != 200) {
        return;
      }
      
      var courseData = courseResponse.body;
      
      // Get progress
      final progressResponse = await lmsService.getCourseProgress(courseId);
      if (progressResponse.statusCode == 200 && progressResponse.body != null) {
        final progressData = progressResponse.body;
        final progress = (progressData['progress'] ?? 0).toDouble();
        newCourseProgress[courseId] = progress;
      } else {
        final status = enrollment['status'] ?? 'enrolled';
        newCourseProgress[courseId] = status == 'completed' ? 100.0 : 0.0;
      }
      
      // Handle featured image
      if (courseData['featured_media'] != null && courseData['featured_media'] != 0) {
        final mediaId = courseData['featured_media'];
        final cachedUrl = mediaCache.getCachedUrl(mediaId);
        if (cachedUrl != null) {
          courseData['featured_image_url'] = cachedUrl;
        }
      }
      
      final course = LLMSCourseModel.fromJson(courseData);
      newCourses.add(course);
    } catch (e) {
      print('Error fetching course $courseId: $e');
    }
  }
  
  /// Clear cache and reload
  void clearCache() {
    _lastFetchTime = null;
    _isInitialLoad = true;
    loadMyCoursesWithCache(forceRefresh: true);
  }
  
  /// Set selected tab
  void setSelectedTab(int index) {
    selectedTab.value = index;
  }
  
  /// Get courses for current tab
  List<LLMSCourseModel> getCoursesForTab() {
    switch (selectedTab.value) {
      case 1:
        return inProgressCourses;
      case 2:
        return completedCourses;
      case 3:
        return notStartedCourses;
      default:
        return allCourses;
    }
  }
  
  /// Set sorting
  void setSorting(String sort, String order) {
    sortBy.value = sort;
    sortOrder.value = order;
    _sortCourses();
  }
  
  /// Navigate to course learning
  void goToCourseLearning(int courseId) {
    Get.toNamed(
      AppRouter.getLearning(),
      arguments: {'id': courseId},
    );
  }
  
  /// Navigate to course detail
  void goToCourseDetail(int courseId) {
    Get.toNamed(
      AppRouter.getCourseDetail(),
      arguments: {'id': courseId},
    );
  }
  
  /// Continue learning (go to last accessed lesson)
  Future<void> continueLearning(int courseId) async {
    // For now, just go to learning page
    // TODO: Implement last accessed lesson tracking
    goToCourseLearning(courseId);
  }
  
  /// Unenroll from course
  Future<void> unenrollFromCourse(int courseId) async {
    Get.dialog(
      AlertDialog(
        title: Text('Unenroll from Course'),
        content: Text('Are you sure you want to unenroll from this course? Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await _performUnenroll(courseId);
            },
            child: Text('Unenroll', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  /// Perform unenrollment
  Future<void> _performUnenroll(int courseId) async {
    try {
      final response = await lmsService.api.unenrollFromCourse(
        userId: lmsService.currentUserId!,
        courseId: courseId,
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        // Remove from lists
        _allCourses.removeWhere((c) => c.id == courseId);
        _inProgressCourses.removeWhere((c) => c.id == courseId);
        _completedCourses.removeWhere((c) => c.id == courseId);
        _notStartedCourses.removeWhere((c) => c.id == courseId);
        
        // Remove progress data
        courseProgress.remove(courseId);
        enrollmentData.remove(courseId);
        
        showToast('Successfully unenrolled from course');
      } else {
        showToast('Failed to unenroll from course', isError: true);
      }
    } catch (e) {
      showToast('Error unenrolling from course', isError: true);
    }
  }
  
  /// Get progress percentage for a course
  double getProgressForCourse(int courseId) {
    return courseProgress[courseId] ?? 0.0;
  }
  
  /// Get enrollment date for a course
  String getEnrollmentDate(int courseId) {
    final progress = courseProgress[courseId] ?? 0.0;
    final enrollment = enrollmentData[courseId];
    
    if (enrollment == null) {
      return '';
    }
    
    String dateStr;
    String prefix = '';
    
    if (progress >= 100) {
      // For completed courses, show completion date with "Completed:" prefix
      dateStr = enrollment['date_updated'] ?? enrollment['date_created'] ?? '';
      prefix = 'Completed: ';
    } else if (progress > 0) {
      // For in-progress courses, show last activity date with "Last Activity:" prefix
      dateStr = enrollment['date_updated'] ?? enrollment['date_created'] ?? '';
      prefix = 'Last Activity: ';
    } else {
      // For not started courses, show enrollment date with "Enrolled:" prefix
      dateStr = enrollment['date_created'] ?? '';
      prefix = 'Enrolled: ';
    }
    
    if (dateStr.isEmpty) return '';
    
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      // Show relative time for recent dates
      String relativeTime;
      if (diff.inDays == 0) {
        relativeTime = 'Today';
      } else if (diff.inDays == 1) {
        relativeTime = 'Yesterday';
      } else if (diff.inDays < 7) {
        relativeTime = '${diff.inDays} days ago';
      } else if (diff.inDays < 30) {
        relativeTime = '${(diff.inDays / 7).floor()} weeks ago';
      } else {
        relativeTime = '${date.day}/${date.month}/${date.year}';
      }
      
      return prefix + relativeTime;
    } catch (e) {
      return '';
    }
  }
  
  /// Get status text for a course
  String getStatusText(int courseId) {
    final progress = getProgressForCourse(courseId);
    
    if (progress >= 100) {
      return 'Completed';
    } else if (progress > 0) {
      return 'In Progress (${progress.toStringAsFixed(0)}%)';
    } else {
      return 'Not Started';
    }
  }
  
  /// Get status color for a course
  Color getStatusColor(int courseId) {
    final progress = getProgressForCourse(courseId);
    
    if (progress >= 100) {
      return Colors.green;
    } else if (progress > 0) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }
  
  /// Clear all lists
  void _clearAllLists() {
    _allCourses.clear();
    _inProgressCourses.clear();
    _completedCourses.clear();
    _notStartedCourses.clear();
    courseProgress.clear();
    enrollmentData.clear();
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
  
  /// Get total enrolled courses count
  int get totalCoursesCount => _allCourses.length;
  
  /// Check if user has any courses
  bool get hasAnyCourses => _allCourses.isNotEmpty;
}