/// Assignment model for upcoming LifterLMS REST API support
/// Based on GitHub Issue #313: https://github.com/gocodebox/lifterlms-rest/issues/313
/// Assignments and grade tracking are being considered for future API releases
class LLMSAssignmentModel {
  final int id;
  final String title;
  final String content;
  final String excerpt;
  final String permalink;
  final int courseId;
  final int lessonId;
  final int sectionId;
  final String status;
  final int points;
  final double passingGrade;
  final bool allowUploads;
  final int maxUploads;
  final List<String> allowedExtensions;
  final int maxFileSize;
  final int attemptsAllowed;
  final String instructions;
  
  // Submission data
  final int? currentAttemptId;
  final int? attemptsRemaining;
  final bool? hasPassed;
  final double? currentGrade;
  final String? submissionStatus; // 'not_started', 'in_progress', 'submitted', 'graded'
  final DateTime? lastSubmissionDate;
  
  LLMSAssignmentModel({
    required this.id,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.permalink,
    required this.courseId,
    required this.lessonId,
    required this.sectionId,
    required this.status,
    required this.points,
    required this.passingGrade,
    required this.allowUploads,
    required this.maxUploads,
    required this.allowedExtensions,
    required this.maxFileSize,
    required this.attemptsAllowed,
    required this.instructions,
    this.currentAttemptId,
    this.attemptsRemaining,
    this.hasPassed,
    this.currentGrade,
    this.submissionStatus,
    this.lastSubmissionDate,
  });
  
  factory LLMSAssignmentModel.fromJson(Map<String, dynamic> json) {
    return LLMSAssignmentModel(
      id: json['id'] ?? 0,
      title: json['title']?['rendered'] ?? json['title'] ?? '',
      content: json['content']?['rendered'] ?? json['content'] ?? '',
      excerpt: json['excerpt']?['rendered'] ?? json['excerpt'] ?? '',
      permalink: json['permalink'] ?? '',
      courseId: json['course_id'] ?? 0,
      lessonId: json['lesson_id'] ?? 0,
      sectionId: json['section_id'] ?? 0,
      status: json['status'] ?? 'publish',
      points: json['points'] ?? 100,
      passingGrade: (json['passing_grade'] ?? 65).toDouble(),
      allowUploads: json['allow_uploads'] ?? true,
      maxUploads: json['max_uploads'] ?? 5,
      allowedExtensions: List<String>.from(json['allowed_extensions'] ?? 
        ['pdf', 'doc', 'docx', 'txt', 'jpg', 'png', 'zip']),
      maxFileSize: json['max_file_size'] ?? 10485760, // 10MB default
      attemptsAllowed: json['attempts_allowed'] ?? 0, // 0 = unlimited
      instructions: json['instructions'] ?? '',
      currentAttemptId: json['current_attempt_id'],
      attemptsRemaining: json['attempts_remaining'],
      hasPassed: json['has_passed'],
      currentGrade: json['current_grade']?.toDouble(),
      submissionStatus: json['submission_status'],
      lastSubmissionDate: json['last_submission_date'] != null 
        ? DateTime.tryParse(json['last_submission_date'])
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
      'course_id': courseId,
      'lesson_id': lessonId,
      'section_id': sectionId,
      'status': status,
      'points': points,
      'passing_grade': passingGrade,
      'allow_uploads': allowUploads,
      'max_uploads': maxUploads,
      'allowed_extensions': allowedExtensions,
      'max_file_size': maxFileSize,
      'attempts_allowed': attemptsAllowed,
      'instructions': instructions,
      'current_attempt_id': currentAttemptId,
      'attempts_remaining': attemptsRemaining,
      'has_passed': hasPassed,
      'current_grade': currentGrade,
      'submission_status': submissionStatus,
      'last_submission_date': lastSubmissionDate?.toIso8601String(),
    };
  }
  
  bool get hasAttemptLimit => attemptsAllowed > 0;
  bool get canRetake => !hasAttemptLimit || (attemptsRemaining ?? 0) > 0;
  bool get isPassed => hasPassed ?? false;
  bool get isSubmitted => submissionStatus == 'submitted' || submissionStatus == 'graded';
  bool get isGraded => submissionStatus == 'graded';
  bool get canUploadFiles => allowUploads;
  String get formattedMaxFileSize => '${(maxFileSize / 1048576).toStringAsFixed(1)} MB';
}