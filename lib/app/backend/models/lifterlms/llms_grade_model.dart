/// Grade model for upcoming LifterLMS REST API support
/// Based on GitHub Issue #313: https://github.com/gocodebox/lifterlms-rest/issues/313
/// This will support student-course, student-assignment, and student-quiz grades
class LLMSGradeModel {
  final int id;
  final int studentId;
  final int postId; // Can be course, lesson, quiz, or assignment ID
  final String postType; // 'course', 'lesson', 'quiz', 'assignment'
  final double grade;
  final double passingGrade;
  final bool passed;
  final int pointsEarned;
  final int pointsPossible;
  final DateTime? earnedDate;
  final DateTime? lastUpdated;
  final String status; // 'incomplete', 'complete', 'passed', 'failed'
  final double progressPercentage;
  final Map<String, dynamic>? metadata;
  
  // Course-specific
  final int? lessonsCompleted;
  final int? totalLessons;
  final int? quizzesCompleted;
  final int? totalQuizzes;
  final int? assignmentsCompleted;
  final int? totalAssignments;
  
  // Quiz-specific
  final int? attemptNumber;
  final int? questionsCorrect;
  final int? totalQuestions;
  
  // Assignment-specific
  final String? submissionStatus;
  final String? instructorFeedback;
  
  LLMSGradeModel({
    required this.id,
    required this.studentId,
    required this.postId,
    required this.postType,
    required this.grade,
    required this.passingGrade,
    required this.passed,
    required this.pointsEarned,
    required this.pointsPossible,
    this.earnedDate,
    this.lastUpdated,
    required this.status,
    required this.progressPercentage,
    this.metadata,
    this.lessonsCompleted,
    this.totalLessons,
    this.quizzesCompleted,
    this.totalQuizzes,
    this.assignmentsCompleted,
    this.totalAssignments,
    this.attemptNumber,
    this.questionsCorrect,
    this.totalQuestions,
    this.submissionStatus,
    this.instructorFeedback,
  });
  
  factory LLMSGradeModel.fromJson(Map<String, dynamic> json) {
    return LLMSGradeModel(
      id: json['id'] ?? 0,
      studentId: json['student_id'] ?? 0,
      postId: json['post_id'] ?? 0,
      postType: json['post_type'] ?? '',
      grade: (json['grade'] ?? 0).toDouble(),
      passingGrade: (json['passing_grade'] ?? 65).toDouble(),
      passed: json['passed'] ?? false,
      pointsEarned: json['points_earned'] ?? 0,
      pointsPossible: json['points_possible'] ?? 100,
      earnedDate: json['earned_date'] != null 
        ? DateTime.tryParse(json['earned_date'])
        : null,
      lastUpdated: json['last_updated'] != null
        ? DateTime.tryParse(json['last_updated'])
        : null,
      status: json['status'] ?? 'incomplete',
      progressPercentage: (json['progress_percentage'] ?? 0).toDouble(),
      metadata: json['metadata'],
      lessonsCompleted: json['lessons_completed'],
      totalLessons: json['total_lessons'],
      quizzesCompleted: json['quizzes_completed'],
      totalQuizzes: json['total_quizzes'],
      assignmentsCompleted: json['assignments_completed'],
      totalAssignments: json['total_assignments'],
      attemptNumber: json['attempt_number'],
      questionsCorrect: json['questions_correct'],
      totalQuestions: json['total_questions'],
      submissionStatus: json['submission_status'],
      instructorFeedback: json['instructor_feedback'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'post_id': postId,
      'post_type': postType,
      'grade': grade,
      'passing_grade': passingGrade,
      'passed': passed,
      'points_earned': pointsEarned,
      'points_possible': pointsPossible,
      'earned_date': earnedDate?.toIso8601String(),
      'last_updated': lastUpdated?.toIso8601String(),
      'status': status,
      'progress_percentage': progressPercentage,
      'metadata': metadata,
      'lessons_completed': lessonsCompleted,
      'total_lessons': totalLessons,
      'quizzes_completed': quizzesCompleted,
      'total_quizzes': totalQuizzes,
      'assignments_completed': assignmentsCompleted,
      'total_assignments': totalAssignments,
      'attempt_number': attemptNumber,
      'questions_correct': questionsCorrect,
      'total_questions': totalQuestions,
      'submission_status': submissionStatus,
      'instructor_feedback': instructorFeedback,
    };
  }
  
  // Helper getters
  bool get isComplete => status == 'complete' || status == 'passed' || status == 'failed';
  bool get isInProgress => status == 'incomplete';
  bool get isCourse => postType == 'course';
  bool get isLesson => postType == 'lesson';
  bool get isQuiz => postType == 'quiz';
  bool get isAssignment => postType == 'assignment';
  
  String get letterGrade {
    if (grade >= 90) return 'A';
    if (grade >= 80) return 'B';
    if (grade >= 70) return 'C';
    if (grade >= 60) return 'D';
    return 'F';
  }
  
  String get formattedGrade => '${grade.toStringAsFixed(1)}%';
  
  String get progressSummary {
    if (isCourse && totalLessons != null) {
      return '${lessonsCompleted ?? 0} of $totalLessons lessons completed';
    }
    if (isQuiz && totalQuestions != null) {
      return '${questionsCorrect ?? 0} of $totalQuestions questions correct';
    }
    return '${progressPercentage.toStringAsFixed(0)}% complete';
  }
}