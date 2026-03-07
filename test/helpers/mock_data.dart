/// Mock data for unit tests.
/// Contains sample JSON objects matching the app's model expectations.
library;

class MockData {
  // -- Course JSON ----------------------------------------------------------

  static Map<String, dynamic> sampleCourseJson({
    int id = 101,
    String title = 'Introduction to Flutter',
    String priceType = 'paid',
    double price = 49.99,
  }) {
    return {
      'id': id,
      'title': {'rendered': title},
      'content': {'rendered': '<p>Full course content here.</p>'},
      'excerpt': {'rendered': 'A short excerpt about the course.'},
      'permalink': 'https://example.com/courses/intro-flutter',
      'slug': 'intro-flutter',
      'status': 'publish',
      'featured_image_url': 'https://example.com/images/flutter.png',
      'date_created': '2025-01-15T10:00:00',
      'date_updated': '2025-06-01T12:00:00',
      'on_sale': false,
      'price': price,
      'regular_price': price,
      'sale_price': 0,
      'price_type': priceType,
      'catalog_visibility': 'catalog_search',
      'categories': [1, 2],
      'tags': [10],
      'tracks': [],
      'difficulties': [],
      'prerequisite': null,
      'prerequisite_track': null,
      'length': {'rendered': '2 hours'},
      'video_embed': null,
      'audio_embed': null,
      'average_rating': 4.5,
      'review_count': 12,
      'enrollment_count': 150,
      'capacity': 500,
      'capacity_enabled': false,
      'capacity_message': {'rendered': ''},
      'access_opens_date': null,
      'access_closes_date': null,
      'enrollment_opens_date': null,
      'enrollment_closes_date': null,
      'enrollment_period': false,
      'time_period': false,
      'restriction_add_on': null,
      'restricted_levels': [],
      'restricted_message': {'rendered': ''},
      'instructors': [
        {
          'id': 1,
          'name': 'Jane Doe',
          'email': 'jane@example.com',
          'username': 'janedoe',
          'first_name': 'Jane',
          'last_name': 'Doe',
          'nickname': 'Jane',
          'display_name': 'Jane Doe',
          'description': 'Senior instructor',
          'avatar_url': 'https://example.com/avatar.png',
          'url': '',
          'link': '',
          'website': '',
          'locale': 'en_US',
          'registered_date': '2024-01-01',
          'roles': ['instructor'],
        }
      ],
      'sections': null,
      'purchasable': true,
      'has_access_plans': true,
      'access_plans': [201, 202],
      'video_src': null,
      'audio_src': null,
      'passing_percentage': 80,
      'has_certificate': true,
    };
  }

  /// A minimal course JSON with many fields missing to test null-safety.
  static Map<String, dynamic> minimalCourseJson() {
    return {
      'id': 1,
      'title': 'Minimal Course',
    };
  }

  // -- Lesson JSON ----------------------------------------------------------

  static Map<String, dynamic> sampleLessonJson({
    int id = 501,
    String title = 'Getting Started with Dart',
  }) {
    return {
      'id': id,
      'title': {'rendered': title},
      'content': {'rendered': '<p>Lesson content.</p>'},
      'excerpt': {'rendered': 'Short lesson excerpt.'},
      'permalink': 'https://example.com/lessons/getting-started',
      'slug': 'getting-started',
      'status': 'publish',
      'course_id': 101,
      'section_id': 10,
      'order': 1,
      'parent_id': null,
      'post_type': 'lesson',
      'drip_method': null,
      'drip_days': 0,
      'drip_date': null,
      'public': false,
      'points': 10,
      'quiz_id': null,
      'require_passing_grade': false,
      'assignment_id': null,
      'video_embed': 'https://youtube.com/watch?v=abc123',
      'audio_embed': null,
      'video_src': null,
      'audio_src': null,
      'free_lesson': false,
      'is_complete': false,
      'completed_date': null,
      'progress_percentage': null,
    };
  }

  // -- User JSON ------------------------------------------------------------

  static Map<String, dynamic> sampleUserJson({
    int userId = 42,
    String login = 'johndoe',
    String email = 'john@example.com',
    String displayName = 'John Doe',
  }) {
    return {
      'user_id': userId,
      'user_login': login,
      'user_email': email,
      'user_display_name': displayName,
    };
  }

  // -- ResponseV2 JSON ------------------------------------------------------

  static Map<String, dynamic> sampleResponseV2Json({
    String status = 'success',
    String message = 'Data retrieved successfully',
    List<dynamic>? items,
  }) {
    return {
      'status': status,
      'message': message,
      'data': {
        'items': items ?? [
          {'id': 1, 'name': 'Item One'},
          {'id': 2, 'name': 'Item Two'},
        ],
      },
    };
  }

  // -- Category JSON --------------------------------------------------------

  static Map<String, dynamic> sampleCategoryJson({
    int id = 5,
    String name = 'Programming',
  }) {
    return {
      'id': id,
      'name': name,
      'slug': 'programming',
      'description': 'Courses about programming',
      'count': 12,
      'parent': 0,
    };
  }
}
