/// Quiz model for upcoming LifterLMS REST API quiz support
/// Based on PR #346: https://github.com/gocodebox/lifterlms-rest/pull/346
class LLMSQuizModel {
  final int id;
  final String title;
  final String content;
  final String permalink;
  final int courseId;
  final int lessonId;
  final String status;
  final int questionsPerPage;
  final bool randomizeQuestions;
  final bool randomizeAnswers;
  final int timeLimit;
  final int attemptsAllowed;
  final double passingPercentage;
  final bool showCorrectAnswers;
  final String showResultsOn; // 'completion', 'failed', 'passed'
  final int pointsPerQuestion;
  final int totalPoints;
  final int totalQuestions;
  
  // Quiz attempt tracking
  final int? currentAttemptId;
  final int? attemptsRemaining;
  final bool? hasPassed;
  final double? highestGrade;
  final double? lastGrade;
  
  LLMSQuizModel({
    required this.id,
    required this.title,
    required this.content,
    required this.permalink,
    required this.courseId,
    required this.lessonId,
    required this.status,
    required this.questionsPerPage,
    required this.randomizeQuestions,
    required this.randomizeAnswers,
    required this.timeLimit,
    required this.attemptsAllowed,
    required this.passingPercentage,
    required this.showCorrectAnswers,
    required this.showResultsOn,
    required this.pointsPerQuestion,
    required this.totalPoints,
    required this.totalQuestions,
    this.currentAttemptId,
    this.attemptsRemaining,
    this.hasPassed,
    this.highestGrade,
    this.lastGrade,
  });
  
  factory LLMSQuizModel.fromJson(Map<String, dynamic> json) {
    // Debug logging
    print('LLMSQuizModel.fromJson - Parsing quiz data:');
    print('  id: ${json['id']} (${json['id'].runtimeType})');
    print('  title: ${json['title']} (${json['title'].runtimeType})');
    print('  course_id: ${json['course_id']} (${json['course_id'].runtimeType})');
    print('  lesson_id: ${json['lesson_id']} (${json['lesson_id'].runtimeType})');
    print('  questions_per_page: ${json['questions_per_page']} (${json['questions_per_page'].runtimeType})');
    print('  time_limit: ${json['time_limit']} (${json['time_limit'].runtimeType})');
    print('  allowed_attempts: ${json['allowed_attempts']} (${json['allowed_attempts'].runtimeType})');
    print('  attempts_allowed: ${json['attempts_allowed']} (${json['attempts_allowed'].runtimeType})');
    print('  points: ${json['points']} (${json['points'].runtimeType})');
    print('  points_per_question: ${json['points_per_question']} (${json['points_per_question'].runtimeType})');
    print('  total_points: ${json['total_points']} (${json['total_points'].runtimeType})');
    print('  question_count: ${json['question_count']} (${json['question_count'].runtimeType})');
    print('  total_questions: ${json['total_questions']} (${json['total_questions'].runtimeType})');
    
    // Helper function to safely parse int from string or number
    int? parseIntSafe(dynamic value, int? defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value) ?? defaultValue;
      }
      if (value is num) return value.toInt();
      return defaultValue;
    }
    
    // Handle passing_grade which might be string or number or empty
    double passingGrade = 65.0;
    if (json['passing_grade'] != null && json['passing_grade'] != '') {
      if (json['passing_grade'] is String) {
        passingGrade = double.tryParse(json['passing_grade']) ?? 65.0;
      } else if (json['passing_grade'] is num) {
        passingGrade = json['passing_grade'].toDouble();
      }
    } else if (json['passing_percentage'] != null && json['passing_percentage'] != '') {
      if (json['passing_percentage'] is String) {
        passingGrade = double.tryParse(json['passing_percentage']) ?? 65.0;
      } else if (json['passing_percentage'] is num) {
        passingGrade = json['passing_percentage'].toDouble();
      }
    }
    
    return LLMSQuizModel(
      id: parseIntSafe(json['id'], 0) ?? 0,
      title: json['title'] is String ? json['title'] : (json['title']?['rendered'] ?? ''),
      content: json['content'] is String ? json['content'] : (json['content']?['rendered'] ?? ''),
      permalink: json['permalink'] ?? '',
      courseId: parseIntSafe(json['course_id'], 0) ?? 0,
      lessonId: parseIntSafe(json['lesson_id'], 0) ?? 0,
      status: json['status'] ?? 'publish',
      questionsPerPage: parseIntSafe(json['questions_per_page'], 1) ?? 1,
      randomizeQuestions: json['randomize_questions'] ?? false,
      randomizeAnswers: json['randomize_answers'] ?? false,
      timeLimit: parseIntSafe(json['time_limit'], 0) ?? 0,
      attemptsAllowed: parseIntSafe(json['allowed_attempts'] ?? json['attempts_allowed'], 0) ?? 0,
      passingPercentage: passingGrade,
      showCorrectAnswers: json['show_correct_answers'] ?? true,
      showResultsOn: json['show_results'] ?? 'completion',
      pointsPerQuestion: parseIntSafe(json['points'] ?? json['points_per_question'], 1) ?? 1,
      totalPoints: parseIntSafe(json['total_points'], 0) ?? 0,
      totalQuestions: parseIntSafe(json['question_count'] ?? json['total_questions'], 0) ?? 0,
      currentAttemptId: parseIntSafe(json['current_attempt_id'], null),
      attemptsRemaining: parseIntSafe(json['remaining_attempts'] ?? json['attempts_remaining'], null),
      hasPassed: json['has_passed'],
      highestGrade: json['highest_grade'] != null 
          ? (json['highest_grade'] is String 
              ? double.tryParse(json['highest_grade']) 
              : (json['highest_grade'] as num?)?.toDouble())
          : null,
      lastGrade: json['last_grade'] != null
          ? (json['last_grade'] is String
              ? double.tryParse(json['last_grade'])
              : (json['last_grade'] as num?)?.toDouble())
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'permalink': permalink,
      'course_id': courseId,
      'lesson_id': lessonId,
      'status': status,
      'questions_per_page': questionsPerPage,
      'randomize_questions': randomizeQuestions,
      'randomize_answers': randomizeAnswers,
      'time_limit': timeLimit,
      'attempts_allowed': attemptsAllowed,
      'passing_percentage': passingPercentage,
      'show_correct_answers': showCorrectAnswers,
      'show_results': showResultsOn,
      'points_per_question': pointsPerQuestion,
      'total_points': totalPoints,
      'total_questions': totalQuestions,
      'current_attempt_id': currentAttemptId,
      'attempts_remaining': attemptsRemaining,
      'has_passed': hasPassed,
      'highest_grade': highestGrade,
      'last_grade': lastGrade,
    };
  }
  
  bool get hasTimeLimit => timeLimit > 0;
  bool get hasAttemptLimit => attemptsAllowed > 0;
  bool get canRetake => !hasAttemptLimit || (attemptsRemaining ?? 0) > 0;
  bool get isPassed => hasPassed ?? false;
}