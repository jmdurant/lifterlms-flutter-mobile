import 'package:flutter_app/app/backend/models/lifterlms/llms_instructor_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_section_model.dart';

class LLMSCourseModel {
  final int id;
  final String title;
  final String content;
  final String excerpt;
  final String permalink;
  final String slug;
  final String status;
  final String featuredImage;
  final DateTime dateCreated;
  final DateTime dateModified;
  final bool onSale;
  final double price;
  final double regularPrice;
  final double salePrice;
  final String priceType; // 'free', 'paid', 'members'
  final String catalogVisibility;
  final List<int> categories;
  final List<int> tags;
  final List<int> tracks;
  final List<int> difficulties;
  final int? prerequisite;
  final int? prerequisiteTrack;
  final String length; // Course length as string (e.g., "2 hours", "45 minutes")
  final String? videoEmbed;
  final String? audioEmbed;
  final double averageRating;
  final int reviewCount;
  final int enrollmentCount;
  final int capacity;
  final bool capacityEnabled;
  final String capacityMessage;
  final DateTime? accessOpensDate;
  final DateTime? accessClosesDate;
  final DateTime? enrollmentOpensDate;
  final DateTime? enrollmentClosesDate;
  final bool enrollmentPeriod;
  final bool timePeriod;
  final String? restrictionAddOn;
  final List<int> restrictedLevels;
  final String restrictionMessage;
  final List<LLMSInstructorModel> instructors;
  final List<LLMSSectionModel>? sections;
  
  // Additional LifterLMS specific fields
  final bool purchasable;
  final bool hasAccessPlans;
  final List<int>? accessPlans;
  final String? videoSrc;
  final String? audioSrc;
  final double passingPercentage;
  final bool hasCertificate;
  
  LLMSCourseModel({
    required this.id,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.permalink,
    required this.slug,
    required this.status,
    required this.featuredImage,
    required this.dateCreated,
    required this.dateModified,
    required this.onSale,
    required this.price,
    required this.regularPrice,
    required this.salePrice,
    required this.priceType,
    required this.catalogVisibility,
    required this.categories,
    required this.tags,
    required this.tracks,
    required this.difficulties,
    this.prerequisite,
    this.prerequisiteTrack,
    required this.length,
    this.videoEmbed,
    this.audioEmbed,
    required this.averageRating,
    required this.reviewCount,
    required this.enrollmentCount,
    required this.capacity,
    required this.capacityEnabled,
    required this.capacityMessage,
    this.accessOpensDate,
    this.accessClosesDate,
    this.enrollmentOpensDate,
    this.enrollmentClosesDate,
    required this.enrollmentPeriod,
    required this.timePeriod,
    this.restrictionAddOn,
    required this.restrictedLevels,
    required this.restrictionMessage,
    required this.instructors,
    this.sections,
    required this.purchasable,
    required this.hasAccessPlans,
    this.accessPlans,
    this.videoSrc,
    this.audioSrc,
    this.passingPercentage = 70.0,
    this.hasCertificate = false,
  });
  
  factory LLMSCourseModel.fromJson(Map<String, dynamic> json) {
    try {
      // Parse ID - might be string or int
      final parsedId = json['id'] is String ? int.tryParse(json['id']) ?? 0 : json['id'] ?? 0;
      
      return LLMSCourseModel(
        id: parsedId,
        title: _extractRendered(json['title']),
      content: _extractRendered(json['content']),
      excerpt: _extractRendered(json['excerpt']),
      permalink: json['permalink'] ?? '',
      slug: json['slug'] ?? '',
      status: json['status'] ?? 'publish',
      featuredImage: _extractFeaturedImage(json),
      dateCreated: DateTime.tryParse(json['date_created'] ?? json['date'] ?? '') ?? DateTime.now(),
      dateModified: DateTime.tryParse(json['date_updated'] ?? json['date_modified'] ?? json['modified'] ?? '') ?? DateTime.now(),
      onSale: json['on_sale'] ?? false,
      price: _parseDouble(json['price']),
      regularPrice: _parseDouble(json['regular_price']),
      salePrice: _parseDouble(json['sale_price']),
      priceType: json['price_type'] ?? 'free',
      catalogVisibility: json['catalog_visibility'] ?? 'catalog_search',
      categories: _parseIntList(json['categories']),
      tags: _parseIntList(json['tags']),
      tracks: _parseIntList(json['tracks']),
      difficulties: _parseIntList(json['difficulties']),
      prerequisite: json['prerequisite'],
      prerequisiteTrack: json['prerequisite_track'],
      length: _extractRendered(json['length']),
      videoEmbed: json['video_embed'],
      audioEmbed: json['audio_embed'],
      averageRating: _parseDouble(json['average_rating']),
      reviewCount: _parseInt(json['review_count']),
      enrollmentCount: _parseInt(json['enrollment_count']),
      capacity: _parseInt(json['capacity']),
      capacityEnabled: json['capacity_enabled'] ?? false,
      capacityMessage: _extractRendered(json['capacity_message']),
      accessOpensDate: json['access_opens_date'] != null 
          ? DateTime.tryParse(json['access_opens_date']) 
          : null,
      accessClosesDate: json['access_closes_date'] != null
          ? DateTime.tryParse(json['access_closes_date'])
          : null,
      enrollmentOpensDate: json['enrollment_opens_date'] != null
          ? DateTime.tryParse(json['enrollment_opens_date'])
          : null,
      enrollmentClosesDate: json['enrollment_closes_date'] != null
          ? DateTime.tryParse(json['enrollment_closes_date'])
          : null,
      enrollmentPeriod: json['enrollment_period'] ?? false,
      timePeriod: json['time_period'] ?? false,
      restrictionAddOn: json['restriction_add_on'],
      restrictedLevels: _parseIntList(json['restricted_levels']),
      restrictionMessage: _extractRendered(json['restricted_message']),
      instructors: _parseInstructors(json['instructors']),
      sections: (json['sections'] as List<dynamic>?)
          ?.map((e) => LLMSSectionModel.fromJson(e))
          .toList(),
      purchasable: json['purchasable'] ?? true,
      hasAccessPlans: json['has_access_plans'] ?? false,
      accessPlans: json['access_plans'] != null 
          ? _parseIntList(json['access_plans'])
          : null,
      videoSrc: json['video_src'],
      audioSrc: json['audio_src'],
      passingPercentage: (json['passing_percentage'] ?? 70).toDouble(),
      hasCertificate: json['has_certificate'] ?? false,
    );
    } catch (e, stack) {
      print('Error parsing LLMSCourseModel: $e');
      print('JSON data: $json');
      print('Stack trace: $stack');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': {'rendered': title},
      'content': {'rendered': content},
      'excerpt': {'rendered': excerpt},
      'permalink': permalink,
      'slug': slug,
      'status': status,
      'featured_image': featuredImage,
      'date_created': dateCreated.toIso8601String(),
      'date_modified': dateModified.toIso8601String(),
      'on_sale': onSale,
      'price': price,
      'regular_price': regularPrice,
      'sale_price': salePrice,
      'price_type': priceType,
      'catalog_visibility': catalogVisibility,
      'categories': categories,
      'tags': tags,
      'tracks': tracks,
      'difficulties': difficulties,
      'prerequisite': prerequisite,
      'prerequisite_track': prerequisiteTrack,
      'length': length,
      'video_embed': videoEmbed,
      'audio_embed': audioEmbed,
      'average_rating': averageRating,
      'review_count': reviewCount,
      'enrollment_count': enrollmentCount,
      'capacity': capacity,
      'capacity_enabled': capacityEnabled,
      'capacity_message': capacityMessage,
      'access_opens_date': accessOpensDate?.toIso8601String(),
      'access_closes_date': accessClosesDate?.toIso8601String(),
      'enrollment_opens_date': enrollmentOpensDate?.toIso8601String(),
      'enrollment_closes_date': enrollmentClosesDate?.toIso8601String(),
      'enrollment_period': enrollmentPeriod,
      'time_period': timePeriod,
      'restriction_add_on': restrictionAddOn,
      'restricted_levels': restrictedLevels,
      'restriction_message': restrictionMessage,
      'instructors': instructors.map((e) => e.toJson()).toList(),
      'sections': sections?.map((e) => e.toJson()).toList(),
      'purchasable': purchasable,
      'has_access_plans': hasAccessPlans,
      'access_plans': accessPlans,
      'video_src': videoSrc,
      'audio_src': audioSrc,
    };
  }
  
  static List<int> _parseIntList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((item) {
        if (item is int) return item;
        if (item is String) return int.tryParse(item) ?? 0;
        return 0;
      }).where((item) => item != 0).toList();
    }
    return [];
  }
  
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is Map) return 0.0; // Handle object case
    return 0.0;
  }
  
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is Map) {
      // Try to extract 'rendered' field for objects like length
      if (value.containsKey('rendered')) {
        return _parseInt(value['rendered']);
      }
      return 0;
    }
    return 0;
  }
  
  static String _extractRendered(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map && value.containsKey('rendered')) {
      return value['rendered']?.toString() ?? '';
    }
    return value.toString();
  }
  
  static String _extractFeaturedImage(Map<String, dynamic> json) {
    // First check if we already have a direct featured_image_url (from our manual fetch)
    if (json['featured_image_url'] != null && json['featured_image_url'] is String) {
      return json['featured_image_url'];
    }
    
    // Check if WordPress _embedded data is available
    if (json['_embedded'] != null && json['_embedded'] is Map) {
      final embedded = json['_embedded'] as Map;
      
      // Look for wp:featuredmedia in embedded data
      if (embedded['wp:featuredmedia'] != null && embedded['wp:featuredmedia'] is List) {
        final mediaList = embedded['wp:featuredmedia'] as List;
        if (mediaList.isNotEmpty && mediaList[0] is Map) {
          final media = mediaList[0] as Map;
          
          // Try to get the source URL from various possible locations
          if (media['source_url'] != null) {
            return media['source_url'].toString();
          }
          
          // Check media_details for different sizes
          if (media['media_details'] != null && media['media_details'] is Map) {
            final details = media['media_details'] as Map;
            if (details['sizes'] != null && details['sizes'] is Map) {
              final sizes = details['sizes'] as Map;
              // Try to get the best available size
              final largeUrl = sizes['large']?['source_url'];
              final mediumUrl = sizes['medium']?['source_url'];
              final fullUrl = sizes['full']?['source_url'];
              
              if (largeUrl != null) return largeUrl.toString();
              if (mediumUrl != null) return mediumUrl.toString();
              if (fullUrl != null) return fullUrl.toString();
            }
          }
        }
      }
    }
    
    // If we have a featured_media ID but no URL, return a placeholder
    // with the course title if available
    final mediaId = json['featured_media'];
    if (mediaId != null && mediaId != 0) {
      final title = _extractRendered(json['title']);
      final encodedTitle = Uri.encodeComponent(title.isEmpty ? 'Course' : title.length > 30 ? title.substring(0, 30) : title);
      return 'https://via.placeholder.com/500x300/4A90E2/FFFFFF?text=$encodedTitle';
    }
    
    // Return default placeholder if no featured media
    return 'https://via.placeholder.com/500x300/cccccc/666666?text=No+Image';
  }
  
  static List<LLMSInstructorModel> _parseInstructors(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      // Check if it's a list of IDs or objects
      if (value.isEmpty) return [];
      if (value.first is int) {
        // It's a list of IDs, create simple instructor objects
        return value.map((id) => LLMSInstructorModel(
          id: id,
          name: 'Instructor $id',
          email: '',
          username: 'instructor$id',
          firstName: 'Instructor',
          lastName: '$id',
          nickname: 'Instructor',
          displayName: 'Instructor $id',
          description: '',
          avatarUrl: '',
          url: '',
          link: '',
          website: '',
          locale: 'en_US',
          registeredDate: '',
          roles: ['instructor'],
        )).toList();
      } else if (value.first is Map) {
        // It's a list of instructor objects
        return value.map((e) => LLMSInstructorModel.fromJson(e)).toList();
      }
    }
    return [];
  }
  
  // Helper methods
  bool get isFree => priceType == 'free' || price == 0;
  bool get isPaid => priceType == 'paid' && price > 0;
  bool get isMembersOnly => priceType == 'members';
  bool get hasPrerequisite => prerequisite != null && prerequisite! > 0;
  bool get isEnrollmentOpen {
    if (!enrollmentPeriod) return true;
    final now = DateTime.now();
    if (enrollmentOpensDate != null && now.isBefore(enrollmentOpensDate!)) return false;
    if (enrollmentClosesDate != null && now.isAfter(enrollmentClosesDate!)) return false;
    return true;
  }
  bool get isAccessOpen {
    if (!timePeriod) return true;
    final now = DateTime.now();
    if (accessOpensDate != null && now.isBefore(accessOpensDate!)) return false;
    if (accessClosesDate != null && now.isAfter(accessClosesDate!)) return false;
    return true;
  }
  bool get hasCapacity => !capacityEnabled || enrollmentCount < capacity;
}