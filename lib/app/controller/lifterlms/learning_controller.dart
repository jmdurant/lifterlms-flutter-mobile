import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_lesson_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_section_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_quiz_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_assignment_model.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/backend/api/lifterlms_api.dart';
import 'package:flutter_app/app/helper/dialog_helper.dart';
import 'package:flutter_app/app/util/toast.dart';
import 'package:get/get.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:flutter_app/app/controller/lifterlms/course_detail_controller.dart';
import 'package:flutter_app/app/view/quiz_taking_screen.dart';

class LearningController extends GetxController implements GetxService {
  final LMSService lmsService = LMSService.to;
  
  // Course data
  final Rx<LLMSCourseModel?> currentCourse = Rx<LLMSCourseModel?>(null);
  final RxList<LLMSSectionModel> sections = <LLMSSectionModel>[].obs;
  final Rx<LLMSLessonModel?> currentLesson = Rx<LLMSLessonModel?>(null);
  final RxString cleanedLessonContent = ''.obs; // Cleaned HTML content without navigation/buttons
  final Rx<LLMSQuizModel?> currentQuiz = Rx<LLMSQuizModel?>(null);
  final Rx<LLMSAssignmentModel?> currentAssignment = Rx<LLMSAssignmentModel?>(null);
  
  // Progress tracking
  final RxDouble courseProgress = 0.0.obs;
  final RxInt completedLessons = 0.obs;
  final RxInt totalLessons = 0.obs;
  final RxMap<int, bool> lessonCompletionStatus = <int, bool>{}.obs;
  
  // UI states
  final RxBool isLoading = false.obs;
  final RxBool isLoadingLesson = false.obs;
  final RxBool isLoadingStructure = false.obs;
  final RxBool isCompletingLesson = false.obs;
  final RxBool isEnrolled = false.obs;
  final RxInt selectedSectionIndex = (-1).obs; // -1 means no section is selected/expanded
  final RxInt selectedLessonIndex = 0.obs;
  
  // Navigation
  final RxBool canNavigatePrevious = false.obs;
  final RxBool canNavigateNext = false.obs;
  final RxBool isFirstLesson = false.obs;
  final RxBool isLastLesson = false.obs;
  final RxBool autoAdvanceEnabled = true.obs; // Default to true, load from prefs
  
  // Error handling
  final RxString errorMessage = ''.obs;
  final RxBool hasError = false.obs;
  
  // Course ID
  int courseId = 0;
  
  // Cache management
  DateTime? _lastFetchTime;
  final Duration _cacheExpiry = const Duration(minutes: 10);
  final Map<int, LLMSLessonModel> _lessonCache = {};
  final Map<int, bool> _sectionLoadedStatus = {};
  
  @override
  void onInit() {
    super.onInit();
    // Load auto-advance preference
    _loadAutoAdvancePreference();
    // Initialize with arguments
    initializeFromArguments();
  }
  
  /// Load auto-advance preference from SharedPreferences
  Future<void> _loadAutoAdvancePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      autoAdvanceEnabled.value = prefs.getBool('auto_advance_lessons') ?? true;
      print('LearningController - Auto-advance enabled: ${autoAdvanceEnabled.value}');
    } catch (e) {
      print('Error loading auto-advance preference: $e');
    }
  }
  
  /// Toggle auto-advance setting and save to preferences
  Future<void> toggleAutoAdvance() async {
    autoAdvanceEnabled.value = !autoAdvanceEnabled.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_advance_lessons', autoAdvanceEnabled.value);
      showToast(autoAdvanceEnabled.value 
        ? 'Auto-advance enabled' 
        : 'Auto-advance disabled');
    } catch (e) {
      print('Error saving auto-advance preference: $e');
    }
  }
  
  /// Initialize controller from route arguments
  void initializeFromArguments() {
    final args = Get.arguments;
    int? initialLessonId;
    int? newCourseId;
    bool shouldShowOverview = false;
    
    print('LearningController.initializeFromArguments - arguments: $args');
    
    if (args != null) {
      if (args is Map && args['id'] != null) {
        newCourseId = args['id'];
        // Check if a specific lesson was requested
        if (args['lessonId'] != null) {
          initialLessonId = args['lessonId'];
        }
        // Check if we should show overview (coming from CourseDetail)
        if (args['showOverview'] == true) {
          shouldShowOverview = true;
        }
      } else if (args is int) {
        newCourseId = args;
      }
      
      // Only reload if it's a different course or we don't have a course yet
      if (newCourseId != null && (newCourseId != courseId || currentCourse.value == null)) {
        print('LearningController - Loading course $newCourseId (was: $courseId)');
        courseId = newCourseId;
        
        // Clear previous state
        currentCourse.value = null;
        currentLesson.value = null;
        currentQuiz.value = null;
        currentAssignment.value = null;
        sections.clear();
        _lessonCache.clear();
        _sectionLoadedStatus.clear();
        // Don't clear completion status - we want to preserve it for the session
        // lessonCompletionStatus.clear();
        cleanedLessonContent.value = '';
        
        // Load course data first
        loadCourseData().then((_) {
          // If a specific lesson was requested, load it
          if (initialLessonId != null) {
            print('LearningController - Opening specific lesson: $initialLessonId');
            loadLesson(initialLessonId);
          } else if (!shouldShowOverview) {
            // Only auto-load first lesson if NOT explicitly showing overview
            // Schedule first lesson load AFTER the current build frame
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadFirstLessonIfNeeded();
            });
          } else {
            print('LearningController - Showing course overview (no auto-advance)');
          }
        });
      } else if (courseId == newCourseId && initialLessonId != null) {
        // Same course but different lesson requested
        print('LearningController - Loading lesson $initialLessonId in existing course');
        loadLesson(initialLessonId);
      }
    }
  }
  
  /// Load first lesson if no lesson is currently loaded
  Future<void> _loadFirstLessonIfNeeded() async {
    // Only load if we don't have a lesson yet
    if (currentLesson.value != null) return;
    
    print('LearningController - No lesson loaded, loading first lesson');
    
    // Ensure sections are loaded
    if (sections.isEmpty) {
      await loadCourseSectionsOnly();
    }
    
    // Load first section's lessons if needed
    if (sections.isNotEmpty && sections[0].lessons.isEmpty) {
      await loadSectionOnDemand(sections[0].id ?? 0);
    }
    
    // Load the first lesson
    if (sections.isNotEmpty && sections[0].lessons.isNotEmpty) {
      await loadLesson(sections[0].lessons[0].id);
    }
  }
  
  /// Load course data and check enrollment
  Future<void> loadCourseData() async {
    if (courseId == 0) {
      _handleError('Invalid course ID');
      return;
    }
    
    // Check cache first
    if (_lastFetchTime != null && 
        DateTime.now().difference(_lastFetchTime!) < _cacheExpiry &&
        sections.isNotEmpty) {
      print('LearningController - Using cached course structure');
      // Just refresh progress in background
      loadCourseProgress();
      return;
    }
    
    try {
      isLoading.value = true;
      errorMessage.value = '';
      hasError.value = false;
      
      // Load course details and enrollment in parallel
      await Future.wait([
        loadCourseDetails(),
        checkEnrollmentStatus(),
      ]);
      
      // If enrolled, load course structure (sections only first)
      if (isEnrolled.value) {
        // Load sections first (fast)
        await loadCourseSectionsOnly();
        
        // Show UI immediately after sections are loaded
        isLoading.value = false;
        
        // Force UI update
        sections.refresh();
        
        // Load progress and lessons in background
        Future.microtask(() {
          loadCourseProgress();
          loadSectionLessonsInBackground(); // Load lessons in background
        });
      }
    } catch (e) {
      _handleError('Error loading course: $e');
    } finally {
      if (isLoading.value) {
        isLoading.value = false;
      }
    }
  }
  
  /// Load course details
  Future<void> loadCourseDetails() async {
    final response = await lmsService.api.getCourse(courseId: courseId);
    
    if (response.statusCode == 200) {
      currentCourse.value = LLMSCourseModel.fromJson(response.body);
    } else {
      throw Exception('Failed to load course details');
    }
  }
  
  /// Check enrollment status
  Future<void> checkEnrollmentStatus() async {
    if (!lmsService.isLoggedIn) {
      isEnrolled.value = false;
      return;
    }
    
    final response = await lmsService.api.getEnrollmentStatus(
      userId: lmsService.currentUserId!,
      courseId: courseId,
    );
    
    if (response.statusCode == 200) {
      final status = response.body['status'];
      isEnrolled.value = status == 'enrolled';
    } else if (response.statusCode == 404) {
      isEnrolled.value = false;
    }
  }
  
  /// Enroll in course
  Future<void> enrollInCourse() async {
    if (!lmsService.isLoggedIn) {
      Get.toNamed(AppRouter.login);
      return;
    }
    
    try {
      DialogHelper.showLoading();
      
      final response = await lmsService.enrollInCourse(courseId);
      
      DialogHelper.hideLoading();
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        isEnrolled.value = true;
        showToast('Successfully enrolled in course');
        
        // Load course content after enrollment
        await loadCourseSectionsOnly();
        // Don't load lessons - let user expand sections
        await loadCourseProgress();
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
  
  /// Load only course sections (without lessons) for fast initial display
  Future<void> loadCourseSectionsOnly() async {
    print('LearningController - Loading sections structure for course $courseId');
    
    // First check if CourseDetailController has cached data
    try {
      final courseDetailController = Get.find<CourseDetailController>();
      if (courseDetailController.courseId == courseId && 
          courseDetailController.sections.isNotEmpty) {
        print('LearningController - Using cached sections from CourseDetailController');
        
        sections.clear();
        _sectionLoadedStatus.clear();
        _lessonCache.clear();
        
        // Copy sections and lessons from CourseDetailController
        for (var cachedSection in courseDetailController.sections) {
          final section = LLMSSectionModel(
            id: cachedSection.id,
            title: cachedSection.title,
            order: cachedSection.order,
            courseId: cachedSection.courseId,
            permalink: cachedSection.permalink,
            postType: cachedSection.postType,
            lessons: [], // Initialize with empty list, will be filled below
          );
          
          // Copy lessons if they're already loaded
          if (cachedSection.lessons.isNotEmpty) {
            section.lessons.addAll(cachedSection.lessons);
            _sectionLoadedStatus[section.id ?? 0] = true;
            
            // Cache lessons for quick access
            for (var lesson in cachedSection.lessons) {
              _lessonCache[lesson.id] = lesson;
            }
          } else {
            _sectionLoadedStatus[section.id ?? 0] = false;
          }
          
          sections.add(section);
        }
        
        print('LearningController - Loaded ${sections.length} sections from cache');
        _lastFetchTime = DateTime.now();
        
        // Calculate total lessons from cached data
        totalLessons.value = sections.fold(0, (sum, s) => sum + s.lessons.length);
        
        // Don't automatically load first lesson - let user choose when to start
        // The course overview will be shown by default
        
        return; // Exit early, we have cached data
      }
    } catch (e) {
      print('CourseDetailController not found or no cached data, falling back to API');
    }
    
    // Fall back to API if no cached data
    try {
      final response = await lmsService.api.getSections(courseId: courseId);
      
      if (response.statusCode == 200 && response.body is List) {
        sections.clear();
        _sectionLoadedStatus.clear();
        
        for (var sectionData in response.body) {
          final section = LLMSSectionModel.fromJson(sectionData);
          sections.add(section);
          _sectionLoadedStatus[section.id ?? 0] = false;
        }
        
        print('LearningController - Loaded ${sections.length} sections (structure only)');
        _lastFetchTime = DateTime.now();
      }
    } catch (e) {
      print('Error loading sections: $e');
    }
  }
  
  /// Load lessons for all sections in parallel (background)
  Future<void> loadSectionLessonsInBackground() async {
    if (sections.isEmpty) return;
    
    // Check if we already have all lessons from cache
    bool allLessonsLoaded = sections.every((s) => _sectionLoadedStatus[s.id ?? 0] ?? false);
    if (allLessonsLoaded && totalLessons.value > 0) {
      print('All lessons already loaded from cache');
      return;
    }
    
    // Don't block UI - run truly in background
    Future.delayed(Duration.zero, () async {
      isLoadingStructure.value = true;
      
      try {
        // Only load sections that don't have lessons yet
        bool firstSectionLoaded = false;
        
        // Load first section if needed
        if (sections.isNotEmpty && sections[0].id != null) {
          if (!(_sectionLoadedStatus[sections[0].id] ?? false)) {
            await _loadSectionLessons(sections[0]);
          }
          firstSectionLoaded = true;
          
          // Calculate lessons for first section
          totalLessons.value = sections[0].lessons.length;
          
          // Don't automatically load first lesson - show course overview by default
          // User can click "Start Learning" or select a specific lesson
        }
        
        // Load remaining sections in background (without blocking)
        for (int i = 1; i < sections.length; i++) {
          final section = sections[i];
          if (section.id != null && !(_sectionLoadedStatus[section.id] ?? false)) {
            // Don't await - let them load in background
            _loadSectionLessons(section).then((_) {
              // Update total lessons count as sections load
              totalLessons.value = sections.fold(0, (sum, s) => sum + s.lessons.length);
            });
          }
        }
      } catch (e) {
        print('Error loading section lessons: $e');
      } finally {
        isLoadingStructure.value = false;
      }
    });
  }
  
  /// Load lessons for a specific section
  Future<void> _loadSectionLessons(LLMSSectionModel section) async {
    if (section.id == null || (_sectionLoadedStatus[section.id] ?? false)) {
      return;
    }
    
    try {
      final lessons = await lmsService.courses.getSectionLessons(section.id!);
      // Cache
      for (final l in lessons) {
        _lessonCache[l.id] = l;
      }
      final idx = sections.indexWhere((s) => s.id == section.id);
      if (idx != -1) {
        final s = sections[idx];
        sections[idx] = LLMSSectionModel(
          id: s.id,
          title: s.title,
          courseId: s.courseId,
          order: s.order,
          parentId: s.parentId,
          permalink: s.permalink,
          postType: s.postType,
          lessons: lessons,
        );
        _sectionLoadedStatus[section.id!] = true;
        print('Loaded ${lessons.length} lessons for section ${section.id} (repo)');
        sections.refresh();
      }
    } catch (e) {
      print('Error loading lessons for section ${section.id}: $e');
    }
  }
  
  /// Load lessons for a specific section on demand
  Future<void> loadSectionOnDemand(int sectionId) async {
    final section = sections.firstWhereOrNull((s) => s.id == sectionId);
    if (section != null && !(_sectionLoadedStatus[sectionId] ?? false)) {
      await _loadSectionLessons(section);
    }
  }
  
  /// Load course progress
  Future<void> loadCourseProgress() async {
    if (!lmsService.isLoggedIn) return;
    
    try {
      final response = await lmsService.getCourseProgress(courseId);
      
      if (response.statusCode == 200) {
        final progressData = response.body;
        
        // Update progress
        courseProgress.value = (progressData['progress'] ?? 0).toDouble();
        completedLessons.value = progressData['completed'] ?? 0;
        
        // Update lesson completion status
        if (progressData['lessons'] != null) {
          for (var lesson in progressData['lessons']) {
            lessonCompletionStatus[lesson['id']] = lesson['completed'] ?? false;
          }
        }
      }
    } catch (e) {
      print('Error loading progress: $e');
    }
  }
  
  /// Load specific lesson with caching
  Future<void> loadLesson(int lessonId) async {
    print('LearningController - Loading lesson $lessonId');
    
    // Check cache first
    if (_lessonCache.containsKey(lessonId)) {
      print('LearningController - Using cached lesson data');
      final cachedLesson = _lessonCache[lessonId]!;
      
      // Debug: Show cached lesson details
      print('==================== CACHED LESSON DATA ====================');
      print('Lesson ID: ${cachedLesson.id}');
      print('Title: ${cachedLesson.title}');
      print('Has Quiz: ${cachedLesson.hasQuiz}');
      print('Quiz ID: ${cachedLesson.quizId}');
      print('Has Video: ${cachedLesson.hasVideo}');
      print('Video Embed: ${cachedLesson.videoEmbed}');
      print('Video Src: ${cachedLesson.videoSrc}');
      print('Has Audio: ${cachedLesson.hasAudio}');
      print('Audio Embed: ${cachedLesson.audioEmbed}');
      print('Audio Src: ${cachedLesson.audioSrc}');
      print('\n--- CONTENT FIELD ---');
      print(cachedLesson.content ?? 'No content');
      print('==========================================================');
      
      currentLesson.value = cachedLesson;
      cleanedLessonContent.value = _cleanLessonContent(currentLesson.value?.content);
      updateNavigationStates();
      
      // Load quiz/assignment if needed (even for cached lessons)
      if (cachedLesson.hasQuiz && cachedLesson.quizId != null && cachedLesson.quizId != 0) {
        print('LearningController - Loading quiz ${cachedLesson.quizId} for cached lesson');
        loadQuiz(cachedLesson.quizId!); // Don't await
      }
      
      if (cachedLesson.requiresAssignment && cachedLesson.assignmentId != null) {
        loadAssignment(cachedLesson.assignmentId!); // Don't await
      }
      
      // Prefetch next and previous lessons
      _prefetchAdjacentLessons();
      return;
    }
    
    try {
      isLoadingLesson.value = true;
      
      final response = await lmsService.api.getLesson(lessonId: lessonId);
      
      if (response.statusCode == 200) {
        // Debug: Log the raw lesson data
        print('==================== RAW LESSON DATA ====================');
        print(jsonEncode(response.body));
        print('==========================================================');
        
        final lesson = LLMSLessonModel.fromJson(response.body);
        currentLesson.value = lesson;
        cleanedLessonContent.value = _cleanLessonContent(lesson.content);
        _lessonCache[lessonId] = lesson; // Cache it
        
        print('LearningController - Lesson loaded: ${lesson.title}');
        print('LearningController - Lesson has quiz: ${lesson.hasQuiz}');
        print('LearningController - Quiz ID: ${lesson.quizId}');
        print('LearningController - Requires passing: ${lesson.requiresPassing}');
        print('LearningController - Has video: ${lesson.hasVideo}');
        print('LearningController - Video embed: ${lesson.videoEmbed}');
        print('LearningController - Video src: ${lesson.videoSrc}');
        print('LearningController - Has audio: ${lesson.hasAudio}');
        print('LearningController - Audio embed: ${lesson.audioEmbed}');
        
        // Update navigation states
        updateNavigationStates();
        
        // Load quiz/assignment in background if needed
        if (lesson.hasQuiz && lesson.quizId != null && lesson.quizId != 0) {
          print('LearningController - Loading quiz ${lesson.quizId}');
          loadQuiz(lesson.quizId!); // Don't await
        }
        
        if (lesson.requiresAssignment && lesson.assignmentId != null) {
          loadAssignment(lesson.assignmentId!); // Don't await
        }
        
        // Prefetch adjacent lessons
        _prefetchAdjacentLessons();
      }
    } catch (e) {
      print('Error loading lesson: $e');
      showToast('Error loading lesson', isError: true);
    } finally {
      isLoadingLesson.value = false;
    }
  }
  
  /// Prefetch next and previous lessons for smooth navigation
  Future<void> _prefetchAdjacentLessons() async {
    if (currentLesson.value == null) return;
    
    final futures = <Future>[];
    
    // Prefetch previous lesson
    final prev = findPreviousLesson();
    if (prev != null && !_lessonCache.containsKey(prev.id)) {
      futures.add(_prefetchLesson(prev.id));
    }
    
    // Prefetch next lesson
    final next = findNextLesson();
    if (next != null && !_lessonCache.containsKey(next.id)) {
      futures.add(_prefetchLesson(next.id));
    }
    
    if (futures.isNotEmpty) {
      Future.wait(futures, eagerError: false);
    }
  }
  
  /// Prefetch a lesson silently
  Future<void> _prefetchLesson(int lessonId) async {
    try {
      final response = await lmsService.api.getLesson(lessonId: lessonId);
      if (response.statusCode == 200) {
        _lessonCache[lessonId] = LLMSLessonModel.fromJson(response.body);
        print('Prefetched lesson $lessonId');
      }
    } catch (e) {
      // Silent fail for prefetch
    }
  }
  
  /// Load quiz (if available)
  Future<void> loadQuiz(int quizId) async {
    print('LearningController.loadQuiz - Attempting to load quiz $quizId');
    try {
      final response = await lmsService.api.getQuiz(quizId: quizId);
      
      print('LearningController.loadQuiz - Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('LearningController.loadQuiz - Raw quiz response:');
        print(jsonEncode(response.body));
        
        // The response has quiz data nested under 'quiz' key
        final responseData = response.body;
        final quizData = responseData['quiz'] ?? responseData;
        
        currentQuiz.value = LLMSQuizModel.fromJson(quizData);
        print('LearningController.loadQuiz - Quiz loaded successfully: ${currentQuiz.value?.title}');
        print('LearningController.loadQuiz - Quiz ID: ${currentQuiz.value?.id}');
        print('LearningController.loadQuiz - Total questions: ${currentQuiz.value?.totalQuestions ?? 0}');
      } else if (response.statusCode == 501) {
        // Quiz API not yet available
        print('LearningController.loadQuiz - Quiz API not yet implemented in LifterLMS REST');
        print('LearningController.loadQuiz - Response: ${response.body}');
        
        // For now, clear the quiz so UI doesn't try to show it
        currentQuiz.value = null;
      } else {
        print('LearningController.loadQuiz - Unexpected response: ${response.statusCode}');
        currentQuiz.value = null;
      }
    } catch (e) {
      print('LearningController.loadQuiz - Error: $e');
      currentQuiz.value = null;
    }
  }
  
  /// Load assignment (if available)
  Future<void> loadAssignment(int assignmentId) async {
    try {
      final response = await lmsService.api.getAssignment(assignmentId: assignmentId);
      
      if (response.statusCode == 200) {
        currentAssignment.value = LLMSAssignmentModel.fromJson(response.body);
      } else if (response.statusCode == 501) {
        // Assignment API not yet available
        print('Assignment API not yet implemented');
      }
    } catch (e) {
      print('Error loading assignment: $e');
    }
  }
  
  /// Complete current lesson
  Future<void> completeLesson() async {
    if (currentLesson.value == null) {
      print('ERROR: No current lesson to complete');
      return;
    }
    
    if (!lmsService.isLoggedIn) {
      print('ERROR: User not logged in, cannot complete lesson');
      showToast('Please log in to mark lessons complete', isError: true);
      return;
    }
    
    final lessonId = currentLesson.value!.id;
    print('LearningController.completeLesson - Marking lesson $lessonId as complete');
    
    try {
      isCompletingLesson.value = true;
      
      print('LearningController.completeLesson - Calling API...');
      final response = await lmsService.completeLesson(lessonId);
      
      print('LearningController.completeLesson - Response: ${response.statusCode} - ${response.statusText}');
      print('LearningController.completeLesson - Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        // Update completion status
        lessonCompletionStatus[lessonId] = true;
        completedLessons.value++;
        
        // Update progress
        if (totalLessons.value > 0) {
          courseProgress.value = (completedLessons.value / totalLessons.value) * 100;
        }
        
        print('LearningController.completeLesson - Success! Progress: ${courseProgress.value}%');
        // Don't show toast - button will change to show completed status
        
        // Give user time to see the "Completed" button state (2 seconds)
        await Future.delayed(const Duration(seconds: 2));
        
        // Auto-navigate to next lesson if enabled and available
        if (autoAdvanceEnabled.value && canNavigateNext.value) {
          print('LearningController.completeLesson - Auto-advancing to next lesson');
          await navigateToNextLesson();
        } else if (courseProgress.value >= 100) {
          // Course completed
          showCourseCompletionDialog();
        } else if (!autoAdvanceEnabled.value && canNavigateNext.value) {
          print('LearningController.completeLesson - Auto-advance disabled, staying on current lesson');
        }
      } else {
        print('LearningController.completeLesson - Failed with status: ${response.statusCode}');
        showToast('Failed to mark lesson complete', isError: true);
      }
    } catch (e) {
      print('LearningController.completeLesson - ERROR: $e');
      showToast('Error completing lesson', isError: true);
    } finally {
      isCompletingLesson.value = false;
    }
  }
  
  /// Navigate to previous lesson
  Future<void> navigateToPreviousLesson() async {
    if (!canNavigatePrevious.value) return;
    
    // Find previous lesson
    final previousLesson = findPreviousLesson();
    if (previousLesson != null) {
      // Check if this is a placeholder for loading previous section
      if (previousLesson.id == -2 && previousLesson.sectionId != null) {
        print('LearningController - Loading previous section lessons');
        // Load the previous section's lessons first
        await loadSectionOnDemand(previousLesson.sectionId!);
        
        // Now find the actual previous lesson again
        final actualPreviousLesson = findPreviousLesson();
        if (actualPreviousLesson != null && actualPreviousLesson.id != -2) {
          await loadLesson(actualPreviousLesson.id);
        }
      } else {
        await loadLesson(previousLesson.id);
      }
    }
  }
  
  /// Navigate back to course overview
  void backToOverview() {
    print('LearningController - Going back to course overview');
    // Clear current lesson to show overview
    currentLesson.value = null;
    currentQuiz.value = null;
    currentAssignment.value = null;
    cleanedLessonContent.value = '';
    selectedSectionIndex.value = -1; // Reset section selection
    updateNavigationStates();
  }
  
  /// Navigate to next lesson
  Future<void> navigateToNextLesson() async {
    // Special case: if we're on the overview (no current lesson), start/resume learning
    if (currentLesson.value == null) {
      await startOrResumeLearning();
      return;
    }
    
    if (!canNavigateNext.value) return;
    
    // Find next lesson
    final nextLesson = findNextLesson();
    if (nextLesson != null) {
      // Check if this is a placeholder for loading next section
      if (nextLesson.id == -1 && nextLesson.sectionId != null) {
        print('LearningController - Loading next section lessons');
        // Load the next section's lessons first
        await loadSectionOnDemand(nextLesson.sectionId!);
        
        // Now find the actual next lesson again
        final actualNextLesson = findNextLesson();
        if (actualNextLesson != null && actualNextLesson.id != -1) {
          await loadLesson(actualNextLesson.id);
        }
      } else {
        await loadLesson(nextLesson.id);
      }
    }
  }
  
  /// Start or resume learning from overview
  Future<void> startOrResumeLearning() async {
    print('LearningController - Starting/resuming learning from overview');
    
    // Ensure sections are loaded
    if (sections.isEmpty) {
      await loadCourseSectionsOnly();
    }
    
    // Find first incomplete lesson or start from beginning
    for (var section in sections) {
      if (section.lessons.isEmpty) {
        await loadSectionOnDemand(section.id ?? 0);
      }
      for (var lesson in section.lessons) {
        if (!(lessonCompletionStatus[lesson.id] ?? false)) {
          // Found an incomplete lesson, load it
          print('LearningController - Resuming at incomplete lesson: ${lesson.id}');
          await loadLesson(lesson.id);
          return;
        }
      }
    }
    
    // If all lessons are complete or no progress, start from beginning
    if (sections.isNotEmpty && sections.first.lessons.isNotEmpty) {
      print('LearningController - Starting from first lesson');
      await loadLesson(sections.first.lessons.first.id);
    }
  }
  
  /// Find previous lesson
  LLMSLessonModel? findPreviousLesson() {
    if (currentLesson.value == null) return null;
    
    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      for (int j = 0; j < section.lessons.length; j++) {
        if (section.lessons[j].id == currentLesson.value!.id) {
          // Check current section for previous lesson
          if (j > 0) {
            return section.lessons[j - 1];
          }
          // Check previous section
          if (i > 0) {
            final previousSection = sections[i - 1];
            if (previousSection.lessons.isNotEmpty) {
              return previousSection.lessons.last;
            }
            // If previous section exists but has no lessons loaded
            if (previousSection.id != null) {
              // Return a placeholder to indicate navigation is possible
              return LLMSLessonModel(
                id: -2, // Special ID to indicate "load previous section"
                title: "Previous Section",
                content: "",
                excerpt: "",
                permalink: "",
                slug: "",
                status: "",
                courseId: courseId,
                sectionId: previousSection.id,
                order: 0,
                parentId: null,
                postType: "lesson",
                drippingEnabled: false,
                dripDays: 0,
                dripDate: null,
                dripMethod: null,
                publicPreview: false,
                points: 0,
                hasQuiz: false,
                quizId: null,
                requiresPassing: false,
                requiresAssignment: false,
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
            }
          }
          return null;
        }
      }
    }
    return null;
  }
  
  /// Find next lesson
  LLMSLessonModel? findNextLesson() {
    if (currentLesson.value == null) return null;
    
    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      for (int j = 0; j < section.lessons.length; j++) {
        if (section.lessons[j].id == currentLesson.value!.id) {
          // Check current section for next lesson
          if (j < section.lessons.length - 1) {
            return section.lessons[j + 1];
          }
          // Check next section
          if (i < sections.length - 1) {
            final nextSection = sections[i + 1];
            // If next section has lessons, return the first one
            if (nextSection.lessons.isNotEmpty) {
              return nextSection.lessons.first;
            }
            // If next section has no lessons loaded but exists, we still have a next lesson
            // Return a placeholder to indicate navigation is possible
            if (nextSection.id != null) {
              // We'll load the lessons when navigating
              return LLMSLessonModel(
                id: -1, // Special ID to indicate "load next section"
                title: "Next Section",
                content: "",
                excerpt: "",
                permalink: "",
                slug: "",
                status: "",
                courseId: courseId,
                sectionId: nextSection.id,
                order: 0,
                parentId: null,
                postType: "lesson",
                drippingEnabled: false,
                dripDays: 0,
                dripDate: null,
                dripMethod: null,
                publicPreview: false,
                points: 0,
                hasQuiz: false,
                quizId: null,
                requiresPassing: false,
                requiresAssignment: false,
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
            }
          }
          return null;
        }
      }
    }
    return null;
  }
  
  /// Update navigation states
  void updateNavigationStates() {
    canNavigatePrevious.value = findPreviousLesson() != null;
    canNavigateNext.value = findNextLesson() != null;
    
    // Check if this is the first lesson of the first section
    isFirstLesson.value = false;
    if (currentLesson.value != null && sections.isNotEmpty && sections[0].lessons.isNotEmpty) {
      isFirstLesson.value = currentLesson.value!.id == sections[0].lessons[0].id;
    }
    
    // Check if this is the last lesson of the last section
    isLastLesson.value = false;
    if (currentLesson.value != null && sections.isNotEmpty) {
      final lastSection = sections.last;
      if (lastSection.lessons.isNotEmpty) {
        isLastLesson.value = currentLesson.value!.id == lastSection.lessons.last.id;
      }
    }
    
    // Don't auto-expand sections - let user control expansion manually
    // Keep selectedSectionIndex at -1 to keep all sections collapsed
  }
  
  /// Select lesson from sidebar
  Future<void> selectLesson(int sectionIndex, int lessonIndex) async {
    if (sectionIndex < sections.length && 
        lessonIndex < sections[sectionIndex].lessons.length) {
      selectedSectionIndex.value = sectionIndex;
      selectedLessonIndex.value = lessonIndex;
      
      final lesson = sections[sectionIndex].lessons[lessonIndex];
      await loadLesson(lesson.id);
    }
  }
  
  /// Show course completion dialog
  void showCourseCompletionDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Congratulations! 🎉'),
        content: Text('You have completed the course "${currentCourse.value?.title}"'),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              // Navigate to certificates if available
              if (currentCourse.value?.hasAccessPlans ?? false) {
                // Check for certificate
              }
            },
            child: Text('View Certificate'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              Get.offNamed(AppRouter.myCourses);
            },
            child: Text('My Courses'),
          ),
        ],
      ),
    );
  }
  
  /// Start quiz
  Future<void> startQuiz() async {
    if (currentQuiz.value == null || !lmsService.isLoggedIn) return;
    
    final quiz = currentQuiz.value!;
    final lesson = currentLesson.value;
    
    if (lesson == null) {
      showToast('Error: No lesson context', isError: true);
      return;
    }
    
    // Navigate to quiz taking screen
    Get.to(() => const QuizTakingScreen());
  }
  
  /// Load quiz questions
  Future<void> loadQuizQuestions(int quizId) async {
    try {
      print('LearningController - Loading questions for quiz $quizId');
      
      final response = await lmsService.api.getQuizQuestions(quizId: quizId);
      
      if (response.statusCode == 200) {
        final questionsData = response.body;
        print('LearningController - Loaded ${questionsData['total']} questions');
        
        // TODO: Store questions and display them
        // For now, just log them
        if (questionsData['questions'] != null) {
          for (var question in questionsData['questions']) {
            print('Question ${question['id']}: ${question['content']}');
          }
        }
      } else {
        print('LearningController - Failed to load questions: ${response.body}');
        showToast('Failed to load quiz questions', isError: true);
      }
    } catch (e) {
      print('LearningController - Error loading questions: $e');
      showToast('Error loading quiz questions', isError: true);
    }
  }
  
  /// Start assignment
  Future<void> startAssignment() async {
    if (currentAssignment.value == null || !lmsService.isLoggedIn) return;
    
    // Navigate to assignment page when implemented
    showToast('Assignment feature coming soon!');
  }
  
  /// Refresh course data
  Future<void> refreshData() async {
    await loadCourseData();
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
  
  /// Clean lesson HTML content by removing unnecessary elements
  String _cleanLessonContent(String? htmlContent) {
    if (htmlContent == null || htmlContent.isEmpty) return '';
    
    try {
      final document = html_parser.parse(htmlContent);
      
      // Remove "Back to:" navigation elements
      final backToElements = document.querySelectorAll('.llms-back-to-course, .llms-parent-course-link, .llms-course-navigation');
      for (var element in backToElements) {
        element.remove();
      }
      
      // Remove any paragraph that contains "Back to"
      final paragraphs = document.querySelectorAll('p');
      for (var p in paragraphs) {
        if (p.text.contains('Back to:') || p.text.contains('Back to ')) {
          p.remove();
        }
      }
      
      // Remove "Mark Complete" buttons and wrappers
      final markCompleteElements = document.querySelectorAll('.llms-mark-complete, .mark-complete, .llms-lesson-button-wrapper, .llms-complete-lesson-form');
      for (var element in markCompleteElements) {
        element.remove();
      }
      
      // Remove any buttons with "Mark Complete" text
      final buttons = document.querySelectorAll('button, input[type="submit"], .button');
      for (var button in buttons) {
        if (button.text.contains('Mark Complete') || button.text.contains('Mark complete')) {
          button.remove();
        }
      }
      
      // Remove lesson navigation (previous/next)
      final navElements = document.querySelectorAll('.llms-lesson-navigation, .lesson-navigation, nav.llms-nav-links');
      for (var element in navElements) {
        element.remove();
      }
      
      // Remove favorites elements
      final favoriteElements = document.querySelectorAll('.llms-favorite-wrapper, .llms-favorites-count, .llms-favorite-btn');
      for (var element in favoriteElements) {
        element.remove();
      }
      
      // Remove footer elements
      final footerElements = document.querySelectorAll('footer, .llms-footer, .lesson-footer, .entry-footer');
      for (var element in footerElements) {
        element.remove();
      }
      
      // Remove screen reader text
      final screenReaderText = document.querySelectorAll('.screen-reader-text');
      for (var element in screenReaderText) {
        element.remove();
      }
      
      // Remove any "Return to Course" or similar links
      final links = document.querySelectorAll('a');
      for (var link in links) {
        if (link.text.contains('Return to') || link.text.contains('Back to') || link.text.contains('Course Home')) {
          link.remove();
        }
      }
      
      // Return cleaned HTML
      return document.body?.innerHtml ?? htmlContent;
    } catch (e) {
      print('Error cleaning lesson content: $e');
      return htmlContent;
    }
  }
  
  /// Check if lesson is completed
  bool isLessonCompleted(int lessonId) {
    return lessonCompletionStatus[lessonId] ?? false;
  }
  
  /// Get lesson icon based on type and status
  IconData getLessonIcon(LLMSLessonModel lesson) {
    if (isLessonCompleted(lesson.id)) {
      return Icons.check_circle;
    } else if (lesson.hasQuiz) {
      return Icons.quiz;
    } else if (lesson.requiresAssignment) {
      return Icons.assignment;
    } else if (lesson.hasVideo) {
      return Icons.play_circle_outline;
    } else {
      return Icons.article_outlined;
    }
  }
  
  /// Clear all cached data
  void clearCache() {
    _lessonCache.clear();
    _sectionLoadedStatus.clear();
    _lastFetchTime = null;
  }
  
  /// Force refresh course data
  Future<void> forceRefresh() async {
    clearCache();
    await loadCourseData();
  }
  
  /// Start a quiz (TODO: Implement quiz functionality)
  Future<void> onStartQuiz(int quizId) async {
    // TODO: Implement quiz start functionality
    print('Starting quiz with ID: $quizId');
    Get.snackbar(
      'Coming Soon',
      'Quiz functionality will be implemented soon',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
  
  /// Start an assignment (TODO: Implement assignment functionality)
  Future<void> onStartAssignment(int assignmentId) async {
    // TODO: Implement assignment start functionality
    print('Starting assignment with ID: $assignmentId');
    Get.snackbar(
      'Coming Soon',
      'Assignment functionality will be implemented soon',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
  
  @override
  void onClose() {
    clearCache();
    super.onClose();
  }
}
