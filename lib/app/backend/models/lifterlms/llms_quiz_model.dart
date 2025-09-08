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
    return LLMSQuizModel(
      id: json['id'] ?? 0,
      title: json['title']?['rendered'] ?? json['title'] ?? '',
      content: json['content']?['rendered'] ?? json['content'] ?? '',
      permalink: json['permalink'] ?? '',
      courseId: json['course_id'] ?? 0,
      lessonId: json['lesson_id'] ?? 0,
      status: json['status'] ?? 'publish',
      questionsPerPage: json['questions_per_page'] ?? 1,
      randomizeQuestions: json['randomize_questions'] ?? false,
      randomizeAnswers: json['randomize_answers'] ?? false,
      timeLimit: json['time_limit'] ?? 0,
      attemptsAllowed: json['attempts_allowed'] ?? 0,
      passingPercentage: (json['passing_percentage'] ?? 65).toDouble(),
      showCorrectAnswers: json['show_correct_answers'] ?? true,
      showResultsOn: json['show_results'] ?? 'completion',
      pointsPerQuestion: json['points_per_question'] ?? 1,
      totalPoints: json['total_points'] ?? 0,
      totalQuestions: json['total_questions'] ?? 0,
      currentAttemptId: json['current_attempt_id'],
      attemptsRemaining: json['attempts_remaining'],
      hasPassed: json['has_passed'],
      highestGrade: json['highest_grade']?.toDouble(),
      lastGrade: json['last_grade']?.toDouble(),
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