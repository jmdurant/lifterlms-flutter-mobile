class LLMSInstructorModel {
  final int id;
  final String name;
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final String nickname;
  final String displayName;
  final String description;
  final String avatarUrl;
  final String url;
  final String link;
  final String website;
  final String locale;
  final String registeredDate;
  final List<String> roles;
  final Map<String, dynamic>? meta;
  final Map<String, String>? social;
  final int courseCount;
  final int studentCount;
  final double averageRating;
  final int reviewCount;
  
  LLMSInstructorModel({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.nickname,
    required this.displayName,
    required this.description,
    required this.avatarUrl,
    required this.url,
    required this.link,
    this.website = '',
    required this.locale,
    required this.registeredDate,
    required this.roles,
    this.meta,
    this.social,
    this.courseCount = 0,
    this.studentCount = 0,
    this.averageRating = 0.0,
    this.reviewCount = 0,
  });
  
  factory LLMSInstructorModel.fromJson(Map<String, dynamic> json) {
    return LLMSInstructorModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      nickname: json['nickname'] ?? '',
      displayName: json['display_name'] ?? json['name'] ?? '',
      description: json['description'] ?? '',
      avatarUrl: json['avatar_urls']?['96'] ?? json['avatar_url'] ?? '',
      url: json['url'] ?? '',
      link: json['link'] ?? '',
      website: json['website'] ?? json['user_url'] ?? '',
      locale: json['locale'] ?? 'en_US',
      registeredDate: json['registered_date'] ?? '',
      roles: List<String>.from(json['roles'] ?? ['instructor']),
      meta: json['meta'],
      social: json['social'] != null 
        ? Map<String, String>.from(json['social'].map((key, value) => 
            MapEntry(key.toString(), value?.toString() ?? '')))
        : null,
      courseCount: json['course_count'] ?? json['courses']?.length ?? 0,
      studentCount: json['student_count'] ?? 0,
      averageRating: (json['average_rating'] ?? 0).toDouble(),
      reviewCount: json['review_count'] ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'nickname': nickname,
      'display_name': displayName,
      'description': description,
      'avatar_url': avatarUrl,
      'url': url,
      'link': link,
      'locale': locale,
      'registered_date': registeredDate,
      'roles': roles,
      'meta': meta,
      'social': social,
    };
  }
  
  String get fullName => '$firstName $lastName'.trim();
  bool get isInstructor => roles.contains('instructor');
  bool get isAssistant => roles.contains('instructors_assistant');
}