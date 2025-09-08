import 'package:flutter_app/app/backend/models/lifterlms/llms_lesson_model.dart';

class LLMSSectionModel {
  final int id;
  final String title;
  final int courseId;
  final int order;
  final int? parentId;
  final String permalink;
  final String postType;
  final List<LLMSLessonModel> lessons;
  
  LLMSSectionModel({
    required this.id,
    required this.title,
    required this.courseId,
    required this.order,
    this.parentId,
    required this.permalink,
    required this.postType,
    required this.lessons,
  });
  
  factory LLMSSectionModel.fromJson(Map<String, dynamic> json) {
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
    
    // Handle title - it might be a string or an object with 'rendered'
    String title = '';
    if (json['title'] is String) {
      title = decodeHtmlEntities(json['title']);
    } else if (json['title'] is Map && json['title']['rendered'] != null) {
      title = decodeHtmlEntities(json['title']['rendered']);
    }
    
    return LLMSSectionModel(
      id: json['id'] ?? 0,
      title: title,
      courseId: json['parent_id'] ?? json['course_id'] ?? 0,
      order: json['order'] ?? 0,
      parentId: json['parent_id'],
      permalink: json['permalink'] ?? '',
      postType: json['post_type'] ?? 'section',
      lessons: (json['lessons'] as List<dynamic>?)
          ?.map((e) => LLMSLessonModel.fromJson(e))
          .toList() ?? [],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'course_id': courseId,
      'order': order,
      'parent_id': parentId,
      'permalink': permalink,
      'post_type': postType,
      'lessons': lessons.map((e) => e.toJson()).toList(),
    };
  }
  
  int get lessonCount => lessons.length;
  bool get hasLessons => lessons.isNotEmpty;
}