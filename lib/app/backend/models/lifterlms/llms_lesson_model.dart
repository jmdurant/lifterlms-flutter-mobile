class LLMSLessonModel {
  final int id;
  final String title;
  final String content;
  final String excerpt;
  final String permalink;
  final String slug;
  final String status;
  final int courseId;
  final int sectionId;
  final int order;
  final int? parentId;
  final String postType;
  final bool drippingEnabled;
  final int dripDays;
  final DateTime? dripDate;
  final String? dripMethod;
  final bool publicPreview;
  final int points;
  final bool hasQuiz;
  final int? quizId;
  final bool requiresPassing;
  final bool requiresAssignment;
  final int? assignmentId;
  final String? videoEmbed;
  final String? audioEmbed;
  final String? videoSrc;
  final String? audioSrc;
  final bool freeLesson;
  
  // Progress tracking
  final bool? isComplete;
  final DateTime? completedDate;
  final double? progressPercentage;
  
  LLMSLessonModel({
    required this.id,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.permalink,
    required this.slug,
    required this.status,
    required this.courseId,
    required this.sectionId,
    required this.order,
    this.parentId,
    required this.postType,
    required this.drippingEnabled,
    required this.dripDays,
    this.dripDate,
    this.dripMethod,
    required this.publicPreview,
    required this.points,
    required this.hasQuiz,
    this.quizId,
    required this.requiresPassing,
    required this.requiresAssignment,
    this.assignmentId,
    this.videoEmbed,
    this.audioEmbed,
    this.videoSrc,
    this.audioSrc,
    required this.freeLesson,
    this.isComplete,
    this.completedDate,
    this.progressPercentage,
  });
  
  factory LLMSLessonModel.fromJson(Map<String, dynamic> json) {
    // Helper function to decode HTML entities
    String decodeHtmlEntities(String text) {
      return text
          .replaceAll('&#8217;', "'")
          .replaceAll('&#8216;', "'")
          .replaceAll('&#8220;', '"')
          .replaceAll('&#8221;', '"')
          .replaceAll('&#038;', '&')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#039;', "'")
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&#8211;', '–')
          .replaceAll('&#8212;', '—');
    }
    
    // Handle title, content, excerpt - they might be strings or objects with 'rendered'
    String title = '';
    if (json['title'] is String) {
      title = decodeHtmlEntities(json['title']);
    } else if (json['title'] is Map && json['title']['rendered'] != null) {
      title = decodeHtmlEntities(json['title']['rendered']);
    }
    
    String content = '';
    if (json['content'] is String) {
      content = json['content'];
    } else if (json['content'] is Map && json['content']['rendered'] != null) {
      content = json['content']['rendered'];
    }
    
    String excerpt = '';
    if (json['excerpt'] is String) {
      excerpt = json['excerpt'];
    } else if (json['excerpt'] is Map && json['excerpt']['rendered'] != null) {
      excerpt = json['excerpt']['rendered'];
    }
    
    // Debug logging for video fields
    if (json['video_embed'] != null) {
      print('Lesson ${json['id']} - video_embed: ${json['video_embed']}');
    }
    if (json['video_src'] != null) {
      print('Lesson ${json['id']} - video_src: ${json['video_src']}');
    }
    
    return LLMSLessonModel(
      id: json['id'] ?? 0,
      title: title,
      content: content,
      excerpt: excerpt,
      permalink: json['permalink'] ?? '',
      slug: json['slug'] ?? '',
      status: json['status'] ?? 'publish',
      courseId: json['course_id'] ?? json['parent_course'] ?? 0,
      sectionId: json['section_id'] ?? json['parent_section'] ?? 0,
      order: json['order'] ?? json['menu_order'] ?? 0,
      parentId: json['parent_id'],
      postType: json['post_type'] ?? 'lesson',
      drippingEnabled: json['drip_method'] != null && json['drip_method'] != '',
      dripDays: json['drip_days'] ?? 0,
      dripDate: json['drip_date'] != null 
          ? DateTime.tryParse(json['drip_date'])
          : null,
      dripMethod: json['drip_method'],
      publicPreview: json['public'] ?? json['preview'] ?? false,
      points: json['points'] ?? 0,
      hasQuiz: (json['quiz_id'] != null && json['quiz_id'] != 0) || 
               (json['quiz'] is Map && json['quiz']['id'] != null && json['quiz']['id'] != 0) ||
               (json['quiz'] is int && json['quiz'] != 0),
      quizId: json['quiz_id'] != null && json['quiz_id'] != 0 
          ? json['quiz_id'] 
          : (json['quiz'] is Map ? json['quiz']['id'] : json['quiz']),
      requiresPassing: json['require_passing_grade'] ?? false,
      requiresAssignment: json['assignment'] != null || json['assignment_id'] != null,
      assignmentId: json['assignment_id'] ?? (json['assignment'] is Map ? json['assignment']['id'] : json['assignment']),
      videoEmbed: json['video_embed'],
      audioEmbed: json['audio_embed'],
      videoSrc: json['video_src'],
      audioSrc: json['audio_src'],
      freeLesson: json['free_lesson'] ?? false,
      isComplete: json['is_complete'],
      completedDate: json['completed_date'] != null
          ? DateTime.tryParse(json['completed_date'])
          : null,
      progressPercentage: json['progress_percentage'] != null
          ? (json['progress_percentage'] as num).toDouble()
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'excerpt': excerpt,
      'permalink': permalink,
      'slug': slug,
      'status': status,
      'course_id': courseId,
      'section_id': sectionId,
      'order': order,
      'parent_id': parentId,
      'post_type': postType,
      'drip_method': dripMethod,
      'drip_days': dripDays,
      'drip_date': dripDate?.toIso8601String(),
      'public': publicPreview,
      'points': points,
      'quiz_id': quizId,
      'require_passing_grade': requiresPassing,
      'assignment_id': assignmentId,
      'video_embed': videoEmbed,
      'audio_embed': audioEmbed,
      'video_src': videoSrc,
      'audio_src': audioSrc,
      'free_lesson': freeLesson,
      'is_complete': isComplete,
      'completed_date': completedDate?.toIso8601String(),
      'progress_percentage': progressPercentage,
    };
  }
  
  // Helper methods
  bool get isDripped => drippingEnabled && !isAvailable;
  bool get isAvailable {
    if (!drippingEnabled) return true;
    if (dripDate != null) {
      return DateTime.now().isAfter(dripDate!);
    }
    // For day-based dripping, would need enrollment date to calculate
    return true;
  }
  bool get hasVideo => videoEmbed != null || videoSrc != null;
  bool get hasAudio => audioEmbed != null || audioSrc != null;
  bool get hasMedia => hasVideo || hasAudio;
  bool get isCompleted => isComplete ?? false;
}