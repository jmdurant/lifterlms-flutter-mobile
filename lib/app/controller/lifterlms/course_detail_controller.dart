import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/api/lifterlms_api.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_lesson_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_section_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_instructor_model.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/backend/services/media_cache_service.dart';
import 'package:flutter_app/app/controller/lifterlms/wishlist_controller.dart';
import 'package:flutter_app/app/helper/dialog_helper.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/util/toast.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

class CourseDetailController extends GetxController implements GetxService {
  final LMSService lmsService = LMSService.to;
  final MediaCacheService mediaCache = Get.find<MediaCacheService>();
  
  // Course data
  final Rx<LLMSCourseModel?> course = Rx<LLMSCourseModel?>(null);
  final RxString cleanedContent = ''.obs; // HTML content without syllabus
  final RxList<LLMSSectionModel> sections = <LLMSSectionModel>[].obs;
  final RxList<LLMSInstructorModel> instructors = <LLMSInstructorModel>[].obs;
  final RxList<dynamic> relatedCourses = <dynamic>[].obs;
  final RxList<dynamic> reviews = <dynamic>[].obs;
  
  // Course stats
  final RxInt totalLessons = 0.obs;
  final RxInt totalQuizzes = 0.obs;
  final RxInt totalAssignments = 0.obs;
  final RxInt totalDuration = 0.obs;
  final RxInt enrolledStudents = 0.obs;
  
  // User status
  final RxBool isEnrolled = false.obs;
  final RxBool isInWishlist = false.obs;
  final RxDouble userProgress = 0.0.obs;
  final RxBool hasAccess = false.obs;
  
  // UI states
  final RxBool isLoading = false.obs;
  final RxBool isEnrolling = false.obs;
  final RxInt selectedTab = 0.obs; // 0: Overview, 1: Curriculum, 2: Instructor, 3: Reviews
  
  // Access plans
  final RxList<dynamic> accessPlans = <dynamic>[].obs;
  final Rx<dynamic> selectedAccessPlan = Rx<dynamic>(null);
  
  // Error handling
  final RxString errorMessage = ''.obs;
  final RxBool hasError = false.obs;
  
  // Course ID
  int courseId = 0;
  
  // Cache management to prevent redundant loading
  DateTime? _lastSectionsFetch;
  final Duration _sectionsCacheExpiry = const Duration(minutes: 10);
  
  @override
  void onInit() {
    super.onInit();
    // Always get fresh arguments when controller initializes
    loadCourseFromArguments();
  }
  
  /// Load course from navigation arguments
  void loadCourseFromArguments() {
    final args = Get.arguments;
    print('CourseDetailController._loadCourseFromArguments - arguments: $args, type: ${args.runtimeType}');
    
    int? newCourseId;
    
    if (args != null) {
      if (args is Map && args['id'] != null) {
        newCourseId = args['id'];
        print('CourseDetailController - Got course ID from map: $newCourseId');
      } else if (args is int) {
        newCourseId = args;
        print('CourseDetailController - Got course ID as int: $newCourseId');
      } else if (args is List && args.isNotEmpty) {
        // Handle legacy array format
        newCourseId = args[0];
        print('CourseDetailController - Got course ID from array: $newCourseId');
      }
      
      // Only reload if it's a different course
      if (newCourseId != null && newCourseId != 0) {
        if (newCourseId != courseId) {
          print('CourseDetailController - Loading new course: $newCourseId (was: $courseId)');
          courseId = newCourseId;
          // Clear previous course data
          course.value = null;
          sections.clear();
          instructors.clear();
          reviews.clear();
          relatedCourses.clear();
          loadCourseDetails();
        } else {
          print('CourseDetailController - Same course ID, not reloading');
        }
      } else {
        print('CourseDetailController - Invalid course ID: $newCourseId');
      }
    } else {
      print('CourseDetailController - No arguments provided');
    }
  }
  
  /// Load complete course details
  Future<void> loadCourseDetails() async {
    print('CourseDetailController.loadCourseDetails - courseId: $courseId');
    if (courseId == 0) {
      _handleError('Invalid course ID');
      return;
    }
    
    try {
      isLoading.value = true;
      errorMessage.value = '';
      hasError.value = false;
      
      print('CourseDetailController - Loading course details for ID: $courseId');
      // Load course basic info
      await loadCourse();
      
      // Load additional data in parallel
      await Future.wait([
        loadCourseSections(),
        loadCourseInstructors(),
        loadAccessPlans(),
        checkEnrollmentStatus(),
        checkWishlistStatus(),
        loadCourseReviews(),
        loadRelatedCourses(),
      ]);
      
      // Calculate course stats
      calculateCourseStats();
      
      // Notify UI to rebuild
      update();
      
    } catch (e) {
      _handleError('Error loading course details: $e');
    } finally {
      isLoading.value = false;
      update(); // Notify UI to rebuild
    }
  }
  
  /// Remove syllabus and other unnecessary elements from HTML content
  String _removeSyllabusFromHTML(String? htmlContent) {
    if (htmlContent == null || htmlContent.isEmpty) return '';
    
    try {
      final document = html_parser.parse(htmlContent);
      
      // Remove the syllabus block (contains all sections and lessons)
      final syllabusElements = document.querySelectorAll('.llms-syllabus-wrapper, .wp-block-llms-course-syllabus');
      for (var element in syllabusElements) {
        element.remove();
      }
      
      // Remove individual lesson preview blocks if they exist outside syllabus
      final lessonPreviews = document.querySelectorAll('.llms-lesson-preview');
      for (var element in lessonPreviews) {
        element.remove();
      }
      
      // Remove "Back to:" navigation elements
      final backToElements = document.querySelectorAll('.llms-back-to-course, .llms-parent-course-link');
      for (var element in backToElements) {
        element.remove();
      }
      
      // Remove favorites/favorite count elements (the 0 or 1 indicators in lesson list)
      final favoriteElements = document.querySelectorAll('.llms-favorite-wrapper, .llms-favorites-count, .llms-favorite-btn, .llms-heart-btn');
      for (var element in favoriteElements) {
        element.remove();
      }
      
      // Remove lesson meta elements (contains favorites and other metadata)
      final lessonMeta = document.querySelectorAll('.llms-lesson-meta');
      for (var element in lessonMeta) {
        element.remove();
      }
      
      // Remove screen reader text
      final screenReaderText = document.querySelectorAll('.screen-reader-text');
      for (var element in screenReaderText) {
        element.remove();
      }
      
      // Remove lesson counters (1 of 11, etc)
      final lessonCounters = document.querySelectorAll('.llms-lesson-counter');
      for (var element in lessonCounters) {
        element.remove();
      }
      
      // Remove footer elements
      final footerElements = document.querySelectorAll('footer, .llms-footer, .course-footer, .entry-footer');
      for (var element in footerElements) {
        element.remove();
      }
      
      // Remove navigation elements
      final navElements = document.querySelectorAll('.llms-course-navigation, .llms-lesson-navigation, nav');
      for (var element in navElements) {
        element.remove();
      }
      
      // Remove continue button blocks
      final continueButtons = document.querySelectorAll('.wp-block-llms-course-continue-button, .llms-course-continue-button');
      for (var element in continueButtons) {
        element.remove();
      }
      
      // Return cleaned HTML
      return document.body?.innerHtml ?? htmlContent;
    } catch (e) {
      print('Error removing syllabus from HTML: $e');
      return htmlContent;
    }
  }
  
  /// Parse course HTML content to extract structure immediately
  void _parseCourseSyllabusFromHTML(String? htmlContent) {
    if (htmlContent == null || htmlContent.isEmpty) return;
    
    try {
      print('CourseDetailController - Parsing course structure from HTML');
      final document = html_parser.parse(htmlContent);
      
      // Clear existing sections for placeholder data
      sections.clear();
      
      // Find all section titles
      final sectionElements = document.querySelectorAll('h3.llms-section-title');
      
      for (var sectionElement in sectionElements) {
        final sectionTitle = sectionElement.text.trim();
        if (sectionTitle.isEmpty) continue;
        
        // Find lessons for this section
        final lessons = <LLMSLessonModel>[];
        var nextElement = sectionElement.nextElementSibling;
        
        while (nextElement != null && !nextElement.localName!.contains('h3')) {
          // Look for lesson previews
          final lessonLinks = nextElement.querySelectorAll('a.llms-lesson-link');
          
          for (var lessonLink in lessonLinks) {
            final href = lessonLink.attributes['href'] ?? '';
            final lessonTitleElement = lessonLink.querySelector('.llms-lesson-title');
            final lessonTitle = lessonTitleElement?.text.trim() ?? '';
            
            if (lessonTitle.isNotEmpty) {
              // Extract lesson ID from URL if possible
              // URLs are like: /lesson/course-welcome-19/ where 19 is part of the slug
              // We'll use 0 as placeholder since we can't reliably extract ID from slug
              final lessonId = 0; // Will be updated when real data loads
              
              // Check for quiz/assignment indicators
              final parentSection = lessonLink.parent?.parent;
              final hasQuiz = parentSection?.querySelector('.llms-lesson-has-quiz') != null;
              final hasAssignment = parentSection?.querySelector('.llms-lesson-has-assignment') != null;
              
              // Create placeholder lesson
              final placeholderLesson = LLMSLessonModel(
                id: lessonId,
                title: lessonTitle,
                content: '',
                excerpt: '',
                permalink: href,
                slug: '',
                status: 'publish',
                courseId: courseId,
                sectionId: 0, // Will be updated when real data loads
                order: lessons.length + 1,
                parentId: null,
                postType: 'lesson',
                drippingEnabled: false,
                dripDays: 0,
                dripDate: null,
                dripMethod: null,
                publicPreview: false,
                points: 0,
                hasQuiz: hasQuiz,
                quizId: null,
                requiresPassing: false,
                requiresAssignment: hasAssignment,
                assignmentId: null,
                videoEmbed: null,
                audioEmbed: null,
                videoSrc: null,
                audioSrc: null,
                freeLesson: false,
                isComplete: false,
                completedDate: null,
                progressPercentage: null,
              );
              
              lessons.add(placeholderLesson);
            }
          }
          
          nextElement = nextElement.nextElementSibling;
        }
        
        // Create placeholder section with lessons
        if (lessons.isNotEmpty) {
          final placeholderSection = LLMSSectionModel(
            id: 0, // Will be updated when real data loads
            title: sectionTitle,
            courseId: courseId,
            order: sections.length + 1,
            parentId: courseId,
            permalink: '',
            postType: 'section',
            lessons: lessons,
          );
          
          sections.add(placeholderSection);
        }
      }
      
      print('CourseDetailController - Extracted ${sections.length} sections from HTML');
      
      // Update UI immediately with placeholder data
      update();
      
    } catch (e) {
      print('Error parsing course HTML: $e');
    }
  }
  
  /// Load course basic information
  Future<void> loadCourse() async {
    print('CourseDetailController.loadCourse - Getting course $courseId');
    final response = await lmsService.api.getCourse(courseId: courseId);
    
    print('CourseDetailController.loadCourse - Response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      print('CourseDetailController.loadCourse - Parsing course data');
      
      // Check if we need to fetch the featured image
      var courseData = response.body;
      if (courseData['featured_media'] != null && courseData['featured_media'] != 0) {
        final mediaId = courseData['featured_media'];
        final permalink = courseData['permalink'];
        
        // First check cache
        try {
          final cachedUrl = mediaCache.getCachedUrl(mediaId);
          if (cachedUrl != null) {
            courseData['featured_image_url'] = cachedUrl;
            print('CourseDetailController.loadCourse - Using cached image for media $mediaId: $cachedUrl');
          } else if (permalink != null && permalink.isNotEmpty) {
            // No cache, fetch via oEmbed
            print('CourseDetailController.loadCourse - Fetching image via oEmbed for: $permalink');
            final oEmbedResponse = await lmsService.api.getOEmbedData(courseUrl: permalink);
            
            if (oEmbedResponse.statusCode == 200 && oEmbedResponse.body != null) {
              final thumbnailUrl = oEmbedResponse.body['thumbnail_url'];
              if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
                courseData['featured_image_url'] = thumbnailUrl;
                // Cache the URL for future use
                mediaCache.cacheUrl(mediaId, thumbnailUrl);
                print('CourseDetailController.loadCourse - Fetched image via oEmbed: $thumbnailUrl');
              }
            }
          }
        } catch (e) {
          print('Error fetching course featured image via oEmbed: $e');
        }
      }
      
      course.value = LLMSCourseModel.fromJson(courseData);
      print('CourseDetailController.loadCourse - Course loaded: ${course.value?.title}');
      enrolledStudents.value = course.value?.enrollmentCount ?? 0;
      totalDuration.value = course.value?.length ?? 0;
      
      // Parse HTML content to immediately show course structure
      _parseCourseSyllabusFromHTML(course.value?.content);
      
      // Set cleaned content (without syllabus) for display
      cleanedContent.value = _removeSyllabusFromHTML(course.value?.content);
      
      update(); // Notify UI to rebuild
    } else {
      throw Exception('Failed to load course: ${response.statusCode}');
    }
  }
  
  /// Load course sections and lessons
  Future<void> loadCourseSections() async {
    try {
      print('CourseDetailController.loadCourseSections - Loading sections for course $courseId (sections only)');
      final list = await lmsService.courses.getSections(courseId, forceRefresh: true);
      sections
        ..clear()
        ..addAll(list);
      _lastSectionsFetch = DateTime.now();
    } catch (e) {
      print('Error loading sections: $e');
    }
  }

  /// Load lessons for a section on user demand (expand)
  Future<void> loadSectionOnDemand(int sectionId) async {
    try {
      final lessons = await lmsService.courses.getSectionLessons(sectionId);
      final idx = sections.indexWhere((s) => s.id == sectionId);
      if (idx != -1) {
        final s = sections[idx];
        final updated = LLMSSectionModel(
          id: s.id,
          title: s.title,
          courseId: s.courseId,
          order: s.order,
          parentId: s.parentId,
          permalink: s.permalink,
          postType: s.postType,
          lessons: lessons,
        );
        sections[idx] = updated;
        sections.refresh();
      }
    } catch (e) {
      print('Error loading lessons for section $sectionId: $e');
    }
  }
  
  /// Load course instructors
  Future<void> loadCourseInstructors() async {
    try {
      if (course.value?.instructors != null && course.value!.instructors.isNotEmpty) {
        // Clear existing instructors
        instructors.clear();
        
        // For each instructor ID, fetch the actual user data
        for (var instructor in course.value!.instructors) {
          final instructorId = instructor.id;
          
          // Fetch the actual instructor data from WordPress Users API
          try {
            final response = await lmsService.api.getUsers(params: {
              'include': instructorId.toString(), // Get specific user by ID
            });
            
            if (response.statusCode == 200 && response.body is List && response.body.isNotEmpty) {
              final userData = response.body[0];
              // Create a proper instructor model from the user data
              final fullInstructor = LLMSInstructorModel.fromJson(userData);
              instructors.add(fullInstructor);
              print('Loaded instructor: ${fullInstructor.displayName}');
            } else {
              // If we can't fetch the user, keep the placeholder
              instructors.add(instructor);
            }
          } catch (e) {
            print('Error fetching instructor $instructorId: $e');
            // Keep the placeholder instructor if fetch fails
            instructors.add(instructor);
          }
        }
      }
    } catch (e) {
      print('Error loading instructors: $e');
    }
  }
  
  /// Load access plans
  Future<void> loadAccessPlans() async {
    try {
      final response = await lmsService.api.getAccessPlans(courseId: courseId);
      
      if (response.statusCode == 200) {
        accessPlans.clear();
        if (response.body is List) {
          accessPlans.addAll(response.body);
          if (accessPlans.isNotEmpty) {
            selectedAccessPlan.value = accessPlans.first;
          }
        }
      }
    } catch (e) {
      print('Error loading access plans: $e');
    }
  }
  
  /// Check enrollment status
  Future<void> checkEnrollmentStatus() async {
    if (!lmsService.isLoggedIn) {
      isEnrolled.value = false;
      hasAccess.value = false;
      return;
    }
    
    try {
      final response = await lmsService.api.getEnrollmentStatus(
        userId: lmsService.currentUserId!,
        courseId: courseId,
      );
      
      if (response.statusCode == 200) {
        final status = response.body['status'];
        isEnrolled.value = status == 'enrolled';
        hasAccess.value = isEnrolled.value;
        
        // Get progress if enrolled
        if (isEnrolled.value) {
          await loadUserProgress();
        }
      } else if (response.statusCode == 404) {
        isEnrolled.value = false;
        hasAccess.value = false;
      }
    } catch (e) {
      print('Error checking enrollment: $e');
    }
  }
  
  /// Load user progress
  Future<void> loadUserProgress() async {
    if (!lmsService.isLoggedIn || !isEnrolled.value) return;
    
    try {
      final response = await lmsService.getCourseProgress(courseId);
      
      if (response.statusCode == 200) {
        final progressData = response.body;
        userProgress.value = (progressData['progress'] ?? 0).toDouble();
      }
    } catch (e) {
      print('Error loading progress: $e');
    }
  }
  
  /// Check wishlist status
  Future<void> checkWishlistStatus() async {
    if (!lmsService.isLoggedIn) {
      isInWishlist.value = false;
      return;
    }
    
    if (Get.isRegistered<WishlistController>()) {
      final wishlistController = Get.find<WishlistController>();
      isInWishlist.value = wishlistController.isInWishlist(courseId);
    }
  }
  
  /// Load course reviews
  Future<void> loadCourseReviews() async {
    try {
      final response = await lmsService.api.getCourseReviews(courseId: courseId);
      
      if (response.statusCode == 200) {
        reviews.clear();
        if (response.body is List) {
          reviews.addAll(response.body);
        }
      } else if (response.statusCode == 501) {
        // Reviews not implemented yet
        print('Reviews feature not available');
      }
    } catch (e) {
      print('Error loading reviews: $e');
    }
  }
  
  /// Load related courses
  Future<void> loadRelatedCourses() async {
    try {
      // Get courses from same category
      if (course.value?.categories.isNotEmpty ?? false) {
        final response = await lmsService.api.getCoursesByCategory(
          categoryId: course.value!.categories.first,
          params: {'per_page': '4', 'exclude': courseId.toString()},
        );
        
        if (response.statusCode == 200) {
          relatedCourses.clear();
          if (response.body is List) {
            relatedCourses.addAll(response.body);
          }
        }
      }
    } catch (e) {
      print('Error loading related courses: $e');
    }
  }
  
  /// Calculate course statistics
  void calculateCourseStats() {
    totalLessons.value = 0;
    totalQuizzes.value = 0;
    totalAssignments.value = 0;
    
    for (var section in sections) {
      totalLessons.value += section.lessons.length;
      for (var lesson in section.lessons) {
        if (lesson.hasQuiz) totalQuizzes.value++;
        if (lesson.requiresAssignment) totalAssignments.value++;
      }
    }
  }
  
  /// Enroll in course
  Future<void> enrollInCourse() async {
    print('CourseDetailController.enrollInCourse - Starting enrollment for course $courseId');
    if (!lmsService.isLoggedIn) {
      print('CourseDetailController.enrollInCourse - User not logged in, redirecting to login');
      Get.toNamed(AppRouter.login);
      return;
    }
    
    try {
      isEnrolling.value = true;
      DialogHelper.showLoading();
      
      print('CourseDetailController.enrollInCourse - Calling API to enroll');
      final response = await lmsService.enrollInCourse(courseId);
      
      DialogHelper.hideLoading();
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        isEnrolled.value = true;
        hasAccess.value = true;
        enrolledStudents.value++;
        
        showToast('Successfully enrolled in course');
        
        // Navigate to learning page
        Get.toNamed(
          AppRouter.getLearning(),
          arguments: {'id': courseId},
        );
      } else if (response.statusCode == 400) {
        // Already enrolled
        isEnrolled.value = true;
        hasAccess.value = true;
        showToast('You are already enrolled in this course');
        
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
    } finally {
      isEnrolling.value = false;
    }
  }
  
  /// Toggle wishlist
  Future<void> toggleWishlist() async {
    if (!lmsService.isLoggedIn) {
      Get.toNamed(AppRouter.login);
      return;
    }
    
    if (Get.isRegistered<WishlistController>()) {
      final wishlistController = Get.find<WishlistController>();
      await wishlistController.toggleWishlist(courseId);
      isInWishlist.value = wishlistController.isInWishlist(courseId);
    }
  }
  
  /// Start learning
  void startLearning() {
    print('CourseDetailController.startLearning - Called');
    print('CourseDetailController.startLearning - courseId: $courseId');
    print('CourseDetailController.startLearning - isEnrolled: ${isEnrolled.value}');
    print('CourseDetailController.startLearning - course: ${course.value?.title}');
    
    if (courseId == 0 || course.value == null) {
      print('CourseDetailController.startLearning - ERROR: Invalid course');
      showToast('Course not loaded', isError: true);
      return;
    }
    
    if (!isEnrolled.value) {
      print('CourseDetailController.startLearning - Not enrolled, enrolling first');
      enrollInCourse();
    } else {
      print('CourseDetailController.startLearning - Already enrolled, navigating to learning page');
      print('CourseDetailController.startLearning - Route: ${AppRouter.getLearning()}');
      print('CourseDetailController.startLearning - Arguments: {id: $courseId}');
      
      try {
        Get.toNamed(
          AppRouter.getLearning(),
          arguments: {'id': courseId},
        );
        print('CourseDetailController.startLearning - Navigation successful');
      } catch (e) {
        print('CourseDetailController.startLearning - Navigation ERROR: $e');
        showToast('Failed to open learning page', isError: true);
      }
    }
  }
  
  /// Start method (alias for startLearning, used by view)
  void start() {
    print('CourseDetailController.start - Called, redirecting to startLearning');
    startLearning();
  }
  
  /// View instructor profile
  void viewInstructorProfile(int instructorId) {
    Get.toNamed(
      AppRouter.getInstructorDetail(),
      arguments: {'id': instructorId},
    );
  }
  
  /// Share course
  Future<void> shareCourse() async {
    if (course.value == null) return;
    
    final url = course.value!.permalink;
    final text = 'Check out this course: ${course.value!.title}';
    
    // Use share functionality
    // Share.share('$text\n$url');
  }
  
  /// Open course in browser
  Future<void> openInBrowser() async {
    if (course.value == null) return;
    
    final url = course.value!.permalink;
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      showToast('Could not open course link', isError: true);
    }
  }
  
  /// Change tab
  void changeTab(int index) {
    selectedTab.value = index;
  }
  
  /// Select access plan
  void selectAccessPlan(dynamic plan) {
    selectedAccessPlan.value = plan;
  }
  
  /// Purchase course
  Future<void> purchaseCourse() async {
    if (!lmsService.isLoggedIn) {
      Get.toNamed(AppRouter.login);
      return;
    }
    
    if (selectedAccessPlan.value == null) {
      showToast('Please select a payment plan', isError: true);
      return;
    }
    
    // Navigate to payment controller
    Get.toNamed(
      AppRouter.payment,
      arguments: {
        'course': course.value,
        'access_plan': selectedAccessPlan.value,
      },
    );
  }
  
  /// Write a review
  void writeReview() {
    if (!lmsService.isLoggedIn) {
      Get.toNamed(AppRouter.login);
      return;
    }
    
    if (!isEnrolled.value) {
      showToast('You must be enrolled to write a review', isError: true);
      return;
    }
    
    // Navigate to review page
    Get.toNamed(
      AppRouter.writeReview,
      arguments: {'course_id': courseId},
    );
  }
  
  /// Refresh course details
  Future<void> refreshCourse() async {
    await loadCourseDetails();
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
  
  /// Get button text based on enrollment status
  String getEnrollButtonText() {
    if (isEnrolled.value) {
      return 'Continue Learning';
    } else if (course.value?.isFree ?? false) {
      return 'Enroll for Free';
    } else {
      return 'Enroll Now';
    }
  }
  
  /// Check if course can be purchased
  bool get canPurchase {
    return !isEnrolled.value && 
           (course.value?.isPaid ?? false) && 
           (course.value?.purchasable ?? false);
  }
  
  /// Get course detail (main method)
  Future<void> getCourseDetail() async {
    if (courseId == null) return;
    
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      // Get course details
      final response = await lmsService.api.getCourse(courseId: courseId!);
      
      if (response.statusCode == 200) {
        course.value = LLMSCourseModel.fromJson(response.body);
        
        // Check enrollment status if logged in
        if (lmsService.isLoggedIn) {
          await checkEnrollmentStatus();
        }
      } else {
        _handleError('Failed to load course details');
      }
    } catch (e) {
      _handleError('Error loading course: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Refresh data
  Future<void> refreshData() async {
    await getCourseDetail();
  }
  
  /// Navigate back
  void onBack() {
    Get.back();
  }
  
  /// Toggle wishlist (alternate method name for compatibility)
  Future<void> onToggleWishlist(String id) async {
    await toggleWishlist();
  }
  
  /// Handle get index lesson (for compatibility)
  int handleGetIndexLesson() {
    // Return first lesson index
    return 0;
  }
  
  /// Navigate to learning (for compatibility)
  void onNavigateLearning(dynamic data) {
    // If a specific lesson was clicked, navigate to that lesson
    if (data != null && data is LLMSLessonModel) {
      print('CourseDetailController.onNavigateLearning - Navigating to lesson: ${data.title}');
      Get.toNamed(
        AppRouter.getLearningRoute(),
        arguments: {
          'id': courseId,
          'lessonId': data.id,
          'sectionId': data.sectionId,
        }
      );
    } else {
      // Otherwise just go to the course learning page
      startLearning();
    }
  }
  
  /// Enroll (alias for enrollInCourse)
  void onEnroll() {
    enrollInCourse();
  }
  
  /// Review placeholder data
  Map<String, dynamic>? get review => null;
  String get reviewMessage => 'No reviews yet';
}
