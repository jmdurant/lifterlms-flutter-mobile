import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/helper/dialog_helper.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/util/toast.dart';
import 'package:get/get.dart';

class ReviewController extends GetxController implements GetxService {
  final LMSService lmsService = LMSService.to;
  
  // Review form
  TextEditingController reviewTitleController = TextEditingController();
  TextEditingController reviewContentController = TextEditingController();
  
  // Course info
  final RxInt courseId = 0.obs;
  final RxString courseName = ''.obs;
  
  // Reviews list
  final RxList<dynamic> reviews = <dynamic>[].obs;
  final RxList<dynamic> userReviews = <dynamic>[].obs;
  
  // Rating
  final RxDouble selectedRating = 5.0.obs;
  final RxDouble averageRating = 0.0.obs;
  final RxInt totalReviews = 0.obs;
  final RxMap<int, int> ratingDistribution = <int, int>{
    5: 0,
    4: 0,
    3: 0,
    2: 0,
    1: 0,
  }.obs;
  
  // Filters
  final RxString sortBy = 'recent'.obs; // recent, helpful, rating_high, rating_low
  final RxInt filterRating = 0.obs; // 0 = all, 1-5 = specific rating
  final RxBool verifiedOnly = false.obs;
  
  // UI states
  final RxBool isLoading = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool canReview = false.obs;
  final RxBool hasReviewed = false.obs;
  final RxInt editingReviewId = 0.obs;
  
  // Pagination
  final RxInt currentPage = 1.obs;
  final RxBool hasMoreReviews = true.obs;
  final int reviewsPerPage = 10;
  
  // Helpful votes
  final RxSet<int> helpfulVotes = <int>{}.obs;
  final RxSet<int> reportedReviews = <int>{}.obs;
  
  ScrollController scrollController = ScrollController();
  
  @override
  void onInit() {
    super.onInit();
    
    // Get course ID from arguments
    final args = Get.arguments;
    if (args != null && args['course_id'] != null) {
      courseId.value = args['course_id'];
      courseName.value = args['course_name'] ?? '';
      
      // Check if editing existing review
      if (args['review_id'] != null) {
        editingReviewId.value = args['review_id'];
      }
      
      initialize();
    }
    
    // Setup scroll listener for pagination
    scrollController.addListener(() {
      if (scrollController.position.pixels >= 
          scrollController.position.maxScrollExtent - 200) {
        if (!isLoading.value && hasMoreReviews.value) {
          loadMoreReviews();
        }
      }
    });
  }
  
  @override
  void onClose() {
    reviewTitleController.dispose();
    reviewContentController.dispose();
    scrollController.dispose();
    super.onClose();
  }
  
  /// Initialize review controller
  Future<void> initialize() async {
    await Future.wait([
      loadReviews(),
      checkReviewEligibility(),
      loadUserReview(),
    ]);
    
    if (editingReviewId.value != 0) {
      loadReviewForEditing();
    }
  }
  
  /// Load reviews for the course
  Future<void> loadReviews() async {
    try {
      isLoading.value = true;
      currentPage.value = 1;
      reviews.clear();
      
      final params = <String, dynamic>{
        'page': currentPage.value.toString(),
        'per_page': reviewsPerPage.toString(),
      };
      
      // Add sorting
      switch (sortBy.value) {
        case 'helpful':
          params['orderby'] = 'helpful';
          break;
        case 'rating_high':
          params['orderby'] = 'rating';
          params['order'] = 'desc';
          break;
        case 'rating_low':
          params['orderby'] = 'rating';
          params['order'] = 'asc';
          break;
        default:
          params['orderby'] = 'date';
          params['order'] = 'desc';
      }
      
      // Add filter
      if (filterRating.value > 0) {
        params['rating'] = filterRating.value.toString();
      }
      
      if (verifiedOnly.value) {
        params['verified'] = 'true';
      }
      
      final response = await lmsService.api.getCourseReviews(
        courseId: courseId.value,
      );
      
      if (response.statusCode == 200) {
        if (response.body is List) {
          reviews.addAll(response.body);
          
          // Calculate statistics
          calculateRatingStats();
          
          // Check if more reviews available
          if ((response.body as List).length < reviewsPerPage) {
            hasMoreReviews.value = false;
          }
        }
      } else if (response.statusCode == 501) {
        // Reviews not implemented
        _showReviewsNotAvailable();
      }
    } catch (e) {
      print('Error loading reviews: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Load more reviews (pagination)
  Future<void> loadMoreReviews() async {
    if (!hasMoreReviews.value || isLoading.value) return;
    
    try {
      isLoading.value = true;
      currentPage.value++;
      
      final params = <String, dynamic>{
        'page': currentPage.value.toString(),
        'per_page': reviewsPerPage.toString(),
      };
      
      final response = await lmsService.api.getCourseReviews(
        courseId: courseId.value,
      );
      
      if (response.statusCode == 200) {
        if (response.body is List) {
          reviews.addAll(response.body);
          
          if ((response.body as List).length < reviewsPerPage) {
            hasMoreReviews.value = false;
          }
        }
      }
    } catch (e) {
      print('Error loading more reviews: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Check if user can review the course
  Future<void> checkReviewEligibility() async {
    if (!lmsService.isLoggedIn) {
      canReview.value = false;
      return;
    }
    
    try {
      // Check if user is enrolled
      final response = await lmsService.api.getEnrollmentStatus(
        userId: lmsService.currentUserId!,
        courseId: courseId.value,
      );
      
      if (response.statusCode == 200) {
        final status = response.body['status'];
        // Can review if enrolled and has made progress
        canReview.value = status == 'enrolled';
        
        // Check progress
        if (canReview.value) {
          final progressResponse = await lmsService.getCourseProgress(courseId.value);
          if (progressResponse.statusCode == 200) {
            final progress = progressResponse.body['progress'] ?? 0;
            // Require at least 20% progress to review
            canReview.value = progress >= 20;
          }
        }
      } else {
        canReview.value = false;
      }
    } catch (e) {
      canReview.value = false;
      print('Error checking review eligibility: $e');
    }
  }
  
  /// Load user's review
  Future<void> loadUserReview() async {
    if (!lmsService.isLoggedIn) return;
    
    try {
      // This would need a custom endpoint to get user's review
      // For now, check if user has reviewed by searching through reviews
      final userReview = reviews.firstWhereOrNull(
        (review) => review['user_id'] == lmsService.currentUserId
      );
      
      if (userReview != null) {
        hasReviewed.value = true;
        userReviews.add(userReview);
      }
    } catch (e) {
      print('Error loading user review: $e');
    }
  }
  
  /// Load review for editing
  void loadReviewForEditing() {
    final review = reviews.firstWhereOrNull(
      (r) => r['id'] == editingReviewId.value
    );
    
    if (review != null) {
      reviewTitleController.text = review['title'] ?? '';
      reviewContentController.text = review['content'] ?? '';
      selectedRating.value = (review['rating'] ?? 5).toDouble();
    }
  }
  
  /// Calculate rating statistics
  void calculateRatingStats() {
    if (reviews.isEmpty) return;
    
    double totalRating = 0;
    ratingDistribution.updateAll((key, value) => 0);
    
    for (var review in reviews) {
      final rating = (review['rating'] ?? 0).toInt();
      if (rating > 0 && rating <= 5) {
        ratingDistribution[rating] = (ratingDistribution[rating] ?? 0) + 1;
        totalRating += rating;
      }
    }
    
    totalReviews.value = reviews.length;
    averageRating.value = totalReviews.value > 0 
      ? totalRating / totalReviews.value 
      : 0.0;
  }
  
  /// Submit review
  Future<void> submitReview() async {
    if (!validateReview()) return;
    
    if (!lmsService.isLoggedIn) {
      Get.toNamed(AppRouter.login);
      return;
    }
    
    if (!canReview.value && editingReviewId.value == 0) {
      showToast('You must be enrolled and have made progress to review this course', isError: true);
      return;
    }
    
    try {
      isSubmitting.value = true;
      DialogHelper.showLoading();
      
      final reviewData = {
        'course_id': courseId.value,
        'rating': selectedRating.value.toInt(),
        'title': reviewTitleController.text.trim(),
        'content': reviewContentController.text.trim(),
        'user_id': lmsService.currentUserId,
      };
      
      // This would need a custom endpoint
      await Future.delayed(Duration(seconds: 2));
      
      DialogHelper.hideLoading();
      
      showToast(
        editingReviewId.value != 0 
          ? 'Review updated successfully'
          : 'Review submitted successfully'
      );
      
      // Clear form
      clearForm();
      hasReviewed.value = true;
      
      // Reload reviews
      await loadReviews();
      
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Failed to submit review', isError: true);
    } finally {
      isSubmitting.value = false;
    }
  }
  
  /// Edit review
  void editReview(dynamic review) {
    if (review['user_id'] != lmsService.currentUserId) {
      showToast('You can only edit your own reviews', isError: true);
      return;
    }
    
    editingReviewId.value = review['id'];
    reviewTitleController.text = review['title'] ?? '';
    reviewContentController.text = review['content'] ?? '';
    selectedRating.value = (review['rating'] ?? 5).toDouble();
  }
  
  /// Delete review
  Future<void> deleteReview(int reviewId) async {
    // Show confirmation dialog
    Get.dialog(
      AlertDialog(
        title: Text('Delete Review'),
        content: Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await performDeleteReview(reviewId);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  /// Perform review deletion
  Future<void> performDeleteReview(int reviewId) async {
    try {
      DialogHelper.showLoading();
      
      // This would need a custom endpoint
      await Future.delayed(Duration(seconds: 1));
      
      DialogHelper.hideLoading();
      
      reviews.removeWhere((r) => r['id'] == reviewId);
      userReviews.removeWhere((r) => r['id'] == reviewId);
      hasReviewed.value = false;
      
      showToast('Review deleted successfully');
      
      // Recalculate stats
      calculateRatingStats();
      
    } catch (e) {
      DialogHelper.hideLoading();
      showToast('Failed to delete review', isError: true);
    }
  }
  
  /// Mark review as helpful
  Future<void> markAsHelpful(int reviewId) async {
    if (!lmsService.isLoggedIn) {
      Get.toNamed(AppRouter.login);
      return;
    }
    
    if (helpfulVotes.contains(reviewId)) {
      // Remove vote
      helpfulVotes.remove(reviewId);
      
      // Update review helpful count
      final review = reviews.firstWhere((r) => r['id'] == reviewId);
      review['helpful_count'] = (review['helpful_count'] ?? 1) - 1;
    } else {
      // Add vote
      helpfulVotes.add(reviewId);
      
      // Update review helpful count
      final review = reviews.firstWhere((r) => r['id'] == reviewId);
      review['helpful_count'] = (review['helpful_count'] ?? 0) + 1;
    }
    
    // This would need a custom endpoint to persist
    reviews.refresh();
  }
  
  /// Report review
  Future<void> reportReview(int reviewId) async {
    if (!lmsService.isLoggedIn) {
      Get.toNamed(AppRouter.login);
      return;
    }
    
    if (reportedReviews.contains(reviewId)) {
      showToast('You have already reported this review');
      return;
    }
    
    // Show report dialog
    Get.dialog(
      AlertDialog(
        title: Text('Report Review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Why are you reporting this review?'),
            SizedBox(height: 16),
            ListTile(
              title: Text('Inappropriate content'),
              onTap: () {
                Get.back();
                submitReport(reviewId, 'inappropriate');
              },
            ),
            ListTile(
              title: Text('Spam'),
              onTap: () {
                Get.back();
                submitReport(reviewId, 'spam');
              },
            ),
            ListTile(
              title: Text('Not relevant'),
              onTap: () {
                Get.back();
                submitReport(reviewId, 'irrelevant');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  /// Submit report
  Future<void> submitReport(int reviewId, String reason) async {
    try {
      // This would need a custom endpoint
      await Future.delayed(Duration(seconds: 1));
      
      reportedReviews.add(reviewId);
      showToast('Review reported. Thank you for your feedback.');
      
    } catch (e) {
      showToast('Failed to report review', isError: true);
    }
  }
  
  /// Apply filters
  void applyFilters() {
    loadReviews();
  }
  
  /// Sort reviews
  void sortReviews(String sort) {
    sortBy.value = sort;
    loadReviews();
  }
  
  /// Filter by rating
  void filterByRating(int rating) {
    filterRating.value = rating;
    loadReviews();
  }
  
  /// Toggle verified only
  void toggleVerifiedOnly() {
    verifiedOnly.value = !verifiedOnly.value;
    loadReviews();
  }
  
  /// Clear filters
  void clearFilters() {
    sortBy.value = 'recent';
    filterRating.value = 0;
    verifiedOnly.value = false;
    loadReviews();
  }
  
  /// Validate review
  bool validateReview() {
    if (reviewTitleController.text.trim().isEmpty) {
      showToast('Please enter a review title', isError: true);
      return false;
    }
    
    if (reviewContentController.text.trim().isEmpty) {
      showToast('Please enter your review', isError: true);
      return false;
    }
    
    if (reviewContentController.text.trim().length < 50) {
      showToast('Review must be at least 50 characters', isError: true);
      return false;
    }
    
    return true;
  }
  
  /// Clear form
  void clearForm() {
    reviewTitleController.clear();
    reviewContentController.clear();
    selectedRating.value = 5.0;
    editingReviewId.value = 0;
  }
  
  /// Update rating
  void updateRating(double rating) {
    selectedRating.value = rating;
  }
  
  /// Show reviews not available dialog
  void _showReviewsNotAvailable() {
    Get.dialog(
      AlertDialog(
        title: Text('Reviews Not Available'),
        content: Text(
          'Course reviews are not yet available. '
          'This feature is coming soon to the LifterLMS REST API.',
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
  
  /// Get rating percentage
  double getRatingPercentage(int rating) {
    if (totalReviews.value == 0) return 0;
    return (ratingDistribution[rating] ?? 0) / totalReviews.value * 100;
  }
  
  /// Get rating color
  Color getRatingColor(double rating) {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 3.5) return Colors.lightGreen;
    if (rating >= 2.5) return Colors.orange;
    if (rating >= 1.5) return Colors.deepOrange;
    return Colors.red;
  }
}