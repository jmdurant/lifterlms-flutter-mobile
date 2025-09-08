import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_instructor_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/backend/services/media_cache_service.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/util/toast.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class InstructorDetailController extends GetxController implements GetxService {
  final LMSService lmsService = LMSService.to;
  final MediaCacheService mediaCache = Get.find<MediaCacheService>();
  
  // Instructor data
  final Rx<LLMSInstructorModel?> instructor = Rx<LLMSInstructorModel?>(null);
  final RxList<LLMSCourseModel> instructorCourses = <LLMSCourseModel>[].obs;
  
  // Stats
  final RxInt totalCourses = 0.obs;
  final RxInt totalStudents = 0.obs;
  final RxDouble averageRating = 0.0.obs;
  final RxInt totalReviews = 0.obs;
  
  // UI states
  final RxBool isLoading = false.obs;
  final RxBool isLoadingCourses = false.obs;
  final RxInt selectedTab = 0.obs; // 0: About, 1: Courses, 2: Reviews
  
  // Pagination for courses
  final RxInt currentPage = 1.obs;
  final RxBool hasMoreCourses = true.obs;
  final int coursesPerPage = 10;
  
  // Social links
  final RxMap<String, String> socialLinks = <String, String>{}.obs;
  
  int instructorId = 0;
  ScrollController scrollController = ScrollController();
  
  @override
  void onInit() {
    super.onInit();
    // Get instructor ID from arguments
    final args = Get.arguments;
    if (args != null) {
      if (args is Map && args['id'] != null) {
        instructorId = args['id'];
      } else if (args is int) {
        instructorId = args;
      }
      loadInstructorDetails();
    }
    
    // Setup scroll listener for pagination
    scrollController.addListener(() {
      if (scrollController.position.pixels >= 
          scrollController.position.maxScrollExtent - 200) {
        if (!isLoadingCourses.value && hasMoreCourses.value && selectedTab.value == 1) {
          loadMoreCourses();
        }
      }
    });
  }
  
  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
  
  /// Load instructor details
  Future<void> loadInstructorDetails() async {
    print('InstructorDetailController.loadInstructorDetails - Starting with ID: $instructorId');
    if (instructorId == 0) {
      showToast('Invalid instructor ID', isError: true);
      return;
    }
    
    try {
      isLoading.value = true;
      update(); // Trigger UI rebuild
      print('InstructorDetailController - Setting isLoading to true');
      
      // Load instructor info using WordPress Users API
      print('InstructorDetailController - Fetching user data for ID: $instructorId');
      final response = await lmsService.api.getUsers(params: {
        'include': instructorId.toString(),
      });
      
      print('InstructorDetailController - Response status: ${response.statusCode}');
      print('InstructorDetailController - Response body type: ${response.body.runtimeType}');
      
      if (response.statusCode == 200 && response.body is List && response.body.isNotEmpty) {
        print('InstructorDetailController - Parsing instructor data');
        instructor.value = LLMSInstructorModel.fromJson(response.body[0]);
        print('InstructorDetailController - Instructor loaded: ${instructor.value?.displayName}');
        
        // Extract stats
        totalCourses.value = instructor.value?.courseCount ?? 0;
        totalStudents.value = instructor.value?.studentCount ?? 0;
        averageRating.value = instructor.value?.averageRating ?? 0.0;
        totalReviews.value = instructor.value?.reviewCount ?? 0;
        
        // Extract social links
        extractSocialLinks();
        
        // Load instructor courses
        print('InstructorDetailController - About to load instructor courses');
        await loadInstructorCourses();
        print('InstructorDetailController - Finished loading instructor courses');
      } else if (response.statusCode == 404) {
        print('InstructorDetailController - Instructor not found (404)');
        showToast('Instructor not found', isError: true);
        Get.back();
      } else {
        print('InstructorDetailController - Failed with status: ${response.statusCode}');
        showToast('Failed to load instructor details', isError: true);
      }
    } catch (e) {
      showToast('Error loading instructor details', isError: true);
      print('InstructorDetailController - Error loading instructor: $e');
    } finally {
      print('InstructorDetailController - Setting isLoading to false');
      isLoading.value = false;
      update(); // Trigger UI rebuild
    }
  }
  
  /// Load instructor courses
  Future<void> loadInstructorCourses() async {
    print('InstructorDetailController.loadInstructorCourses - Starting for instructor: $instructorId');
    try {
      isLoadingCourses.value = true;
      currentPage.value = 1;
      instructorCourses.clear();
      
      print('InstructorDetailController - Fetching courses for author: $instructorId');
      // Get courses by instructor/author
      final response = await lmsService.api.getCourses(params: {
        'author': instructorId.toString(),
        'per_page': '100',
      });
      
      print('InstructorDetailController - Courses response status: ${response.statusCode}');
      print('InstructorDetailController - Courses response body type: ${response.body.runtimeType}');
      
      if (response.statusCode == 200) {
        if (response.body is List) {
          print('InstructorDetailController - Found ${response.body.length} courses');
          
          // Collect oEmbed futures for fetching images
          final oEmbedFutures = <Future<void>>[];
          final mediaUrls = <int, String>{};
          
          // First pass: collect media IDs and prepare oEmbed fetches
          for (var courseData in response.body) {
            final mediaId = courseData['featured_media'];
            final permalink = courseData['permalink'];
            
            if (mediaId != null && mediaId != 0) {
              // Check cache first
              final cachedUrl = mediaCache.getCachedUrl(mediaId);
              if (cachedUrl != null) {
                mediaUrls[mediaId] = cachedUrl;
                print('InstructorDetailController - Using cached image for media $mediaId');
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
                        print('InstructorDetailController - Got image via oEmbed: $thumbnailUrl');
                      }
                    }
                  }).catchError((e) {
                    print('Error fetching oEmbed for $permalink: $e');
                  })
                );
              }
            }
          }
          
          // Wait for all oEmbed fetches to complete
          if (oEmbedFutures.isNotEmpty) {
            print('InstructorDetailController - Waiting for ${oEmbedFutures.length} oEmbed fetches');
            await Future.wait(oEmbedFutures);
            print('InstructorDetailController - All oEmbed fetches complete');
          }
          
          // Second pass: parse courses with fetched images
          for (var courseData in response.body) {
            try {
              // Add the fetched image URL to the course data
              final mediaId = courseData['featured_media'];
              if (mediaId != null && mediaUrls.containsKey(mediaId)) {
                courseData['featured_image_url'] = mediaUrls[mediaId];
              }
              
              final course = LLMSCourseModel.fromJson(courseData);
              instructorCourses.add(course);
              print('InstructorDetailController - Added course: ${course.title}');
            } catch (e) {
              print('Error parsing course: $e');
            }
          }
          
          // Check if more courses available
          if ((response.body as List).length < coursesPerPage) {
            hasMoreCourses.value = false;
          }
        }
      }
    } catch (e) {
      print('Error loading instructor courses: $e');
    } finally {
      isLoadingCourses.value = false;
    }
  }
  
  /// Load more courses (pagination)
  Future<void> loadMoreCourses() async {
    if (isLoadingCourses.value || !hasMoreCourses.value) return;
    
    try {
      isLoadingCourses.value = true;
      currentPage.value++;
      
      // Get courses by instructor/author
      final response = await lmsService.api.getCourses(params: {
        'author': instructorId.toString(),
        'per_page': '100',
      });
      
      if (response.statusCode == 200) {
        if (response.body is List) {
          print('InstructorDetailController - Found ${response.body.length} courses');
          
          // Collect oEmbed futures for fetching images
          final oEmbedFutures = <Future<void>>[];
          final mediaUrls = <int, String>{};
          
          // First pass: collect media IDs and prepare oEmbed fetches
          for (var courseData in response.body) {
            final mediaId = courseData['featured_media'];
            final permalink = courseData['permalink'];
            
            if (mediaId != null && mediaId != 0) {
              // Check cache first
              final cachedUrl = mediaCache.getCachedUrl(mediaId);
              if (cachedUrl != null) {
                mediaUrls[mediaId] = cachedUrl;
                print('InstructorDetailController - Using cached image for media $mediaId');
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
                        print('InstructorDetailController - Got image via oEmbed: $thumbnailUrl');
                      }
                    }
                  }).catchError((e) {
                    print('Error fetching oEmbed for $permalink: $e');
                  })
                );
              }
            }
          }
          
          // Wait for all oEmbed fetches to complete
          if (oEmbedFutures.isNotEmpty) {
            print('InstructorDetailController - Waiting for ${oEmbedFutures.length} oEmbed fetches');
            await Future.wait(oEmbedFutures);
            print('InstructorDetailController - All oEmbed fetches complete');
          }
          
          // Second pass: parse courses with fetched images
          for (var courseData in response.body) {
            try {
              // Add the fetched image URL to the course data
              final mediaId = courseData['featured_media'];
              if (mediaId != null && mediaUrls.containsKey(mediaId)) {
                courseData['featured_image_url'] = mediaUrls[mediaId];
              }
              
              final course = LLMSCourseModel.fromJson(courseData);
              instructorCourses.add(course);
              print('InstructorDetailController - Added course: ${course.title}');
            } catch (e) {
              print('Error parsing course: $e');
            }
          }
          
          // Check if more courses available
          if ((response.body as List).length < coursesPerPage) {
            hasMoreCourses.value = false;
          }
        }
      }
    } catch (e) {
      print('Error loading more courses: $e');
    } finally {
      isLoadingCourses.value = false;
    }
  }
  
  /// Extract social links from instructor data
  void extractSocialLinks() {
    if (instructor.value == null) return;
    
    socialLinks.clear();
    
    // Extract from meta or custom fields
    if (instructor.value!.website.isNotEmpty) {
      socialLinks['website'] = instructor.value!.website;
    }
    
    // These would typically come from meta fields
    // For now, using placeholder logic
    final meta = instructor.value!.toJson();
    if (meta['facebook'] != null) {
      socialLinks['facebook'] = meta['facebook'];
    }
    if (meta['twitter'] != null) {
      socialLinks['twitter'] = meta['twitter'];
    }
    if (meta['linkedin'] != null) {
      socialLinks['linkedin'] = meta['linkedin'];
    }
    if (meta['youtube'] != null) {
      socialLinks['youtube'] = meta['youtube'];
    }
  }
  
  /// Change tab
  void changeTab(int index) {
    selectedTab.value = index;
    
    // Load courses if switching to courses tab
    if (index == 1 && instructorCourses.isEmpty) {
      loadInstructorCourses();
    }
  }
  
  /// Navigate to course detail
  void goToCourseDetail(int courseId) {
    Get.toNamed(
      AppRouter.getCourseDetail(),
      arguments: {'id': courseId},
    );
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
  
  /// Contact instructor
  void contactInstructor() {
    if (instructor.value?.email == null) {
      showToast('Contact information not available', isError: true);
      return;
    }
    
    final email = instructor.value!.email;
    final subject = 'Course Inquiry';
    final mailUrl = 'mailto:$email?subject=$subject';
    
    launch(mailUrl);
  }
  
  /// Follow/unfollow instructor
  Future<void> toggleFollow() async {
    if (!lmsService.isLoggedIn) {
      Get.toNamed(AppRouter.login);
      return;
    }
    
    // This would require a custom endpoint
    showToast('Follow feature coming soon');
  }
  
  /// Refresh instructor data
  Future<void> refreshInstructor() async {
    await loadInstructorDetails();
  }
  
  /// Get instructor expertise
  List<String> getExpertise() {
    // This would typically come from instructor meta
    // For now, returning placeholder data based on courses
    final expertise = <String>{};
    
    for (var course in instructorCourses) {
      // Extract from course categories or tags
      if (course.categories.isNotEmpty) {
        // Would need to map category IDs to names
      }
    }
    
    return expertise.toList();
  }
  
  /// Format member since date
  String getMemberSince() {
    if (instructor.value?.registeredDate == null) return 'N/A';
    
    final dateStr = instructor.value!.registeredDate;
    if (dateStr.isEmpty) return 'N/A';
    
    try {
      final date = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      
      return '${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr; // Return original string if parsing fails
    }
  }
  
  /// Get instructor certification badges
  List<String> getCertifications() {
    // This would come from instructor meta or achievements
    // Placeholder for now
    return [];
  }
  
  /// Check if instructor is verified
  bool get isVerified {
    // This would check a verification status
    // For now, checking if they have courses
    return totalCourses.value > 0;
  }
}