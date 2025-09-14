import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_app/app/backend/models/lifterlms/llms_instructor_model.dart';

/// Service to cache and manage media URLs and instructor data
/// This helps avoid repeated failures for private media and provides fallbacks
class MediaCacheService extends GetxService {
  static MediaCacheService get to => Get.find();
  
  late SharedPreferences _prefs;
  final Map<int, String> _memoryCache = {};
  final Map<int, DateTime> _failureCache = {};
  final Map<int, LLMSInstructorModel> _instructorCache = {};
  
  // Cache for media URLs that have been successfully fetched
  // No longer need hardcoded URLs since we're using oEmbed!
  
  Future<MediaCacheService> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCache();
    return this;
  }
  
  /// Load cached media URLs from persistent storage
  Future<void> _loadCache() async {
    final cacheJson = _prefs.getString('media_url_cache');
    if (cacheJson != null) {
      try {
        final cache = json.decode(cacheJson) as Map<String, dynamic>;
        cache.forEach((key, value) {
          final id = int.tryParse(key);
          if (id != null && value is String) {
            _memoryCache[id] = value;
          }
        });
      } catch (e) {
        print('Error loading media cache: $e');
      }
    }
  }
  
  /// Save cache to persistent storage
  Future<void> _saveCache() async {
    try {
      final cache = <String, String>{};
      _memoryCache.forEach((key, value) {
        cache[key.toString()] = value;
      });
      await _prefs.setString('media_url_cache', json.encode(cache));
    } catch (e) {
      print('Error saving media cache: $e');
    }
  }
  
  /// Get media URL from cache
  String? getCachedUrl(int mediaId) {
    // Check memory cache
    return _memoryCache[mediaId];
  }
  
  /// Cache a successfully fetched media URL
  Future<void> cacheUrl(int mediaId, String url) async {
    _memoryCache[mediaId] = url;
    await _saveCache();
  }
  
  /// Record a media fetch failure
  void recordFailure(int mediaId) {
    _failureCache[mediaId] = DateTime.now();
  }
  
  /// Check if we should retry fetching this media
  /// Returns false if we've recently failed to fetch it
  bool shouldRetryFetch(int mediaId) {
    final lastFailure = _failureCache[mediaId];
    if (lastFailure == null) {
      return true;
    }
    
    // Retry after 1 hour
    final hoursSinceFailure = DateTime.now().difference(lastFailure).inHours;
    return hoursSinceFailure >= 1;
  }
  
  /// Get a fallback URL for when media can't be fetched
  String getFallbackUrl(int mediaId, {String? title}) {
    // Generate a placeholder with the title if provided
    final encodedTitle = title != null 
      ? Uri.encodeComponent(title.length > 30 ? title.substring(0, 30) : title)
      : 'Course';
    return 'https://via.placeholder.com/500x300/4A90E2/FFFFFF?text=$encodedTitle';
  }
  
  /// Clear all cached data
  Future<void> clearCache() async {
    _memoryCache.clear();
    _failureCache.clear();
    _instructorCache.clear();
    await _prefs.remove('media_url_cache');
    await _prefs.remove('instructor_cache');
  }
  
  // ===== Instructor Caching Methods =====
  
  /// Cache an instructor
  void cacheInstructor(LLMSInstructorModel instructor) {
    _instructorCache[instructor.id] = instructor;
    // Note: We don't persist instructors to disk as they may change frequently
    // and we want fresh data on app restart
  }
  
  /// Cache multiple instructors
  void cacheInstructors(List<LLMSInstructorModel> instructors) {
    for (var instructor in instructors) {
      _instructorCache[instructor.id] = instructor;
    }
  }
  
  /// Get cached instructor by ID
  LLMSInstructorModel? getCachedInstructor(int id) {
    return _instructorCache[id];
  }
  
  /// Check if instructor is cached
  bool hasInstructorCached(int id) {
    return _instructorCache.containsKey(id);
  }
  
  /// Clear instructor cache
  void clearInstructorCache() {
    _instructorCache.clear();
  }
}