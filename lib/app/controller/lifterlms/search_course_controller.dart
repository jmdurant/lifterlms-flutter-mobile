import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:get/get.dart';
import 'dart:async';

class SearchCourseController extends GetxController implements GetxService {
  final LMSService lmsService = LMSService.to;
  
  // Search
  TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;
  final RxList<LLMSCourseModel> searchResults = <LLMSCourseModel>[].obs;
  final RxList<String> recentSearches = <String>[].obs;
  final RxList<String> popularSearches = <String>[].obs;
  
  // Filters
  final RxList<dynamic> categories = <dynamic>[].obs;
  final RxList<int> selectedCategories = <int>[].obs;
  final RxString priceFilter = 'all'.obs; // all, free, paid
  final RxString levelFilter = 'all'.obs; // all, beginner, intermediate, advanced
  final RxDouble minRating = 0.0.obs;
  final RxString sortBy = 'relevance'.obs; // relevance, date, price, rating, popularity
  final RxString sortOrder = 'desc'.obs;
  
  // UI States
  final RxBool isSearching = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool showFilters = false.obs;
  final RxBool hasSearched = false.obs;
  
  // Pagination
  final RxInt currentPage = 1.obs;
  final RxBool hasMoreResults = true.obs;
  final int resultsPerPage = 10;
  
  // Debounce timer
  Timer? _debounceTimer;
  
  // Scroll controller
  ScrollController scrollController = ScrollController();
  
  @override
  void onInit() {
    super.onInit();
    initializeSearch();
    loadCategories();
    loadPopularSearches();
    loadRecentSearches();
  }
  
  @override
  void onClose() {
    searchController.dispose();
    scrollController.dispose();
    _debounceTimer?.cancel();
    super.onClose();
  }
  
  /// Initialize search
  void initializeSearch() {
    // Setup scroll listener for pagination
    scrollController.addListener(() {
      if (scrollController.position.pixels >= 
          scrollController.position.maxScrollExtent - 200) {
        if (!isLoadingMore.value && hasMoreResults.value) {
          loadMoreResults();
        }
      }
    });
    
    // Setup search listener with debounce
    searchController.addListener(() {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (searchController.text != searchQuery.value) {
          searchQuery.value = searchController.text;
          if (searchQuery.value.isNotEmpty) {
            performSearch();
          } else {
            clearSearch();
          }
        }
      });
    });
  }
  
  /// Load categories for filters
  Future<void> loadCategories() async {
    try {
      final response = await lmsService.api.getCategories();
      
      if (response.statusCode == 200) {
        categories.clear();
        if (response.body is List) {
          categories.addAll(response.body);
        }
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }
  
  /// Load popular searches
  void loadPopularSearches() {
    // These could be fetched from API or stored locally
    popularSearches.value = [
      'Web Development',
      'JavaScript',
      'Python',
      'Data Science',
      'Machine Learning',
      'React',
      'Flutter',
      'WordPress',
    ];
  }
  
  /// Load recent searches from local storage
  void loadRecentSearches() {
    // Load from SharedPreferences
    // For now, using dummy data
    recentSearches.value = [];
  }
  
  /// Save search to recent
  void saveToRecentSearches(String query) {
    if (query.isEmpty) return;
    
    // Remove if already exists
    recentSearches.remove(query);
    
    // Add to beginning
    recentSearches.insert(0, query);
    
    // Keep only last 10
    if (recentSearches.length > 10) {
      recentSearches.removeLast();
    }
    
    // Save to SharedPreferences
    // TODO: Implement SharedPreferences save
  }
  
  /// Perform search
  Future<void> performSearch({bool isNewSearch = true}) async {
    if (searchQuery.value.isEmpty && selectedCategories.isEmpty) return;
    
    if (isNewSearch) {
      currentPage.value = 1;
      hasMoreResults.value = true;
      searchResults.clear();
      hasSearched.value = true;
    }
    
    try {
      isSearching.value = true;
      
      // Build search parameters
      final params = <String, dynamic>{
        'page': currentPage.value.toString(),
        'per_page': resultsPerPage.toString(),
      };
      
      // Add search query
      if (searchQuery.value.isNotEmpty) {
        params['search'] = searchQuery.value;
        saveToRecentSearches(searchQuery.value);
      }
      
      // Add category filters
      if (selectedCategories.isNotEmpty) {
        params['categories'] = selectedCategories.join(',');
      }
      
      // Add price filter
      if (priceFilter.value != 'all') {
        params['price_type'] = priceFilter.value;
      }
      
      // Add level filter
      if (levelFilter.value != 'all') {
        params['difficulty'] = levelFilter.value;
      }
      
      // Add rating filter
      if (minRating.value > 0) {
        params['min_rating'] = minRating.value.toString();
      }
      
      // Add sorting
      if (sortBy.value != 'relevance') {
        params['orderby'] = sortBy.value;
        params['order'] = sortOrder.value;
      }
      
      // Perform search
      final response = await lmsService.api.searchCourses(
        query: searchQuery.value,
        params: params,
      );
      
      if (response.statusCode == 200) {
        if (response.body is List) {
          for (var courseData in response.body) {
            try {
              final course = LLMSCourseModel.fromJson(courseData);
              searchResults.add(course);
            } catch (e) {
              print('Error parsing course: $e');
            }
          }
          
          // Check if more results available
          if ((response.body as List).length < resultsPerPage) {
            hasMoreResults.value = false;
          }
        }
      }
    } catch (e) {
      print('Search error: $e');
    } finally {
      isSearching.value = false;
    }
  }
  
  /// Load more results
  Future<void> loadMoreResults() async {
    if (isLoadingMore.value || !hasMoreResults.value) return;
    
    try {
      isLoadingMore.value = true;
      currentPage.value++;
      await performSearch(isNewSearch: false);
    } finally {
      isLoadingMore.value = false;
    }
  }
  
  /// Clear search
  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
    searchResults.clear();
    hasSearched.value = false;
    currentPage.value = 1;
    hasMoreResults.value = true;
  }
  
  /// Toggle filter visibility
  void toggleFilters() {
    showFilters.value = !showFilters.value;
  }
  
  /// Toggle category selection
  void toggleCategory(int categoryId) {
    if (selectedCategories.contains(categoryId)) {
      selectedCategories.remove(categoryId);
    } else {
      selectedCategories.add(categoryId);
    }
    performSearch();
  }
  
  /// Set price filter
  void setPriceFilter(String filter) {
    priceFilter.value = filter;
    performSearch();
  }
  
  /// Set level filter
  void setLevelFilter(String filter) {
    levelFilter.value = filter;
    performSearch();
  }
  
  /// Set minimum rating
  void setMinimumRating(double rating) {
    minRating.value = rating;
    performSearch();
  }
  
  /// Set sorting
  void setSorting(String sort, String order) {
    sortBy.value = sort;
    sortOrder.value = order;
    performSearch();
  }
  
  /// Clear all filters
  void clearFilters() {
    selectedCategories.clear();
    priceFilter.value = 'all';
    levelFilter.value = 'all';
    minRating.value = 0.0;
    sortBy.value = 'relevance';
    sortOrder.value = 'desc';
    performSearch();
  }
  
  /// Search from suggestion
  void searchFromSuggestion(String suggestion) {
    searchController.text = suggestion;
    searchQuery.value = suggestion;
    performSearch();
  }
  
  /// Clear recent searches
  void clearRecentSearches() {
    recentSearches.clear();
    // TODO: Clear from SharedPreferences
  }
  
  /// Navigate to course detail
  void goToCourseDetail(int courseId) {
    Get.toNamed(
      AppRouter.getCourseDetail(),
      arguments: {'id': courseId},
    );
  }
  
  /// Get active filter count
  int get activeFilterCount {
    int count = 0;
    if (selectedCategories.isNotEmpty) count++;
    if (priceFilter.value != 'all') count++;
    if (levelFilter.value != 'all') count++;
    if (minRating.value > 0) count++;
    return count;
  }
  
  /// Check if filters are applied
  bool get hasActiveFilters => activeFilterCount > 0;
}