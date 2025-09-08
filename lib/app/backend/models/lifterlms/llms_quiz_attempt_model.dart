/// Quiz Attempt model for upcoming LifterLMS REST API support
/// Based on PR #346: https://github.com/gocodebox/lifterlms-rest/pull/346
class LLMSQuizAttemptModel {
  final int id;
  final int quizId;
  final int studentId;
  final int lessonId;
  final int courseId;
  final int attemptNumber;
  final DateTime startDate;
  final DateTime? endDate;
  final String status; // 'incomplete', 'pending', 'complete'
  final double grade;
  final double passingGrade;
  final bool passed;
  final int questionsAnswered;
  final int totalQuestions;
  final int pointsEarned;
  final int totalPoints;
  final String? resultMessage;
  final List<QuizAnswerModel> answers;
  
  LLMSQuizAttemptModel({
    required this.id,
    required this.quizId,
    required this.studentId,
    required this.lessonId,
    required this.courseId,
    required this.attemptNumber,
    required this.startDate,
    this.endDate,
    required this.status,
    required this.grade,
    required this.passingGrade,
    required this.passed,
    required this.questionsAnswered,
    required this.totalQuestions,
    required this.pointsEarned,
    required this.totalPoints,
    this.resultMessage,
    required this.answers,
  });
  
  factory LLMSQuizAttemptModel.fromJson(Map<String, dynamic> json) {
    return LLMSQuizAttemptModel(
      id: json['id'] ?? 0,
      quizId: json['quiz_id'] ?? 0,
      studentId: json['student_id'] ?? 0,
      lessonId: json['lesson_id'] ?? 0,
      courseId: json['course_id'] ?? 0,
      attemptNumber: json['attempt'] ?? 1,
      startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      status: json['status'] ?? 'incomplete',
      grade: (json['grade'] ?? 0).toDouble(),
      passingGrade: (json['passing_grade'] ?? 65).toDouble(),
      passed: json['passed'] ?? false,
      questionsAnswered: json['questions_answered'] ?? 0,
      totalQuestions: json['total_questions'] ?? 0,
      pointsEarned: json['points_earned'] ?? 0,
      totalPoints: json['total_points'] ?? 0,
      resultMessage: json['result_message'],
      answers: (json['answers'] as List<dynamic>?)
          ?.map((e) => QuizAnswerModel.fromJson(e))
          .toList() ?? [],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quiz_id': quizId,
      'student_id': studentId,
      'lesson_id': lessonId,
      'course_id': courseId,
      'attempt': attemptNumber,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status,
      'grade': grade,
      'passing_grade': passingGrade,
      'passed': passed,
      'questions_answered': questionsAnswered,
      'total_questions': totalQuestions,
      'points_earned': pointsEarned,
      'total_points': totalPoints,
      'result_message': resultMessage,
      'answers': answers.map((e) => e.toJson()).toList(),
    };
  }
  
  bool get isComplete => status == 'complete';
  bool get isInProgress => status == 'incomplete';
  bool get isPending => status == 'pending';
  double get progressPercentage => totalQuestions > 0 
      ? (questionsAnswered / totalQuestions * 100) 
      : 0;
  Duration? get duration => endDate != null 
      ? endDate!.difference(startDate) 
      : null;
}

class QuizAnswerModel {
  final int questionId;
  final dynamic answer; // Can be string, int, or list for multiple choice
  final bool correct;
  final int pointsEarned;
  final int pointsPossible;
  
  QuizAnswerModel({
    required this.questionId,
    required this.answer,
    required this.correct,
    required this.pointsEarned,
    required this.pointsPossible,
  });
  
  factory QuizAnswerModel.fromJson(Map<String, dynamic> json) {
    return QuizAnswerModel(
      questionId: json['question_id'] ?? 0,
      answer: json['answer'],
      correct: json['correct'] ?? false,
      pointsEarned: json['points_earned'] ?? 0,
      pointsPossible: json['points_possible'] ?? 1,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'answer': answer,
      'correct': correct,
      'points_earned': pointsEarned,
      'points_possible': pointsPossible,
    };
  }
}