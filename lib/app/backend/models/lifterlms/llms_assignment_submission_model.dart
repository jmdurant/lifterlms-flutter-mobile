/// Assignment Submission model for upcoming LifterLMS REST API support
/// Based on GitHub Issue #313: https://github.com/gocodebox/lifterlms-rest/issues/313
class LLMSAssignmentSubmissionModel {
  final int id;
  final int assignmentId;
  final int studentId;
  final int courseId;
  final int lessonId;
  final int attemptNumber;
  final DateTime submittedDate;
  final DateTime? gradedDate;
  final String status; // 'pending', 'graded', 'passed', 'failed'
  final String? submissionContent;
  final List<AssignmentFileModel> files;
  final double? grade;
  final double passingGrade;
  final int pointsEarned;
  final int pointsPossible;
  final String? instructorFeedback;
  final int? gradedBy;
  final String? gradedByName;
  
  LLMSAssignmentSubmissionModel({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.courseId,
    required this.lessonId,
    required this.attemptNumber,
    required this.submittedDate,
    this.gradedDate,
    required this.status,
    this.submissionContent,
    required this.files,
    this.grade,
    required this.passingGrade,
    required this.pointsEarned,
    required this.pointsPossible,
    this.instructorFeedback,
    this.gradedBy,
    this.gradedByName,
  });
  
  factory LLMSAssignmentSubmissionModel.fromJson(Map<String, dynamic> json) {
    return LLMSAssignmentSubmissionModel(
      id: json['id'] ?? 0,
      assignmentId: json['assignment_id'] ?? 0,
      studentId: json['student_id'] ?? 0,
      courseId: json['course_id'] ?? 0,
      lessonId: json['lesson_id'] ?? 0,
      attemptNumber: json['attempt'] ?? 1,
      submittedDate: DateTime.parse(json['submitted_date'] ?? DateTime.now().toIso8601String()),
      gradedDate: json['graded_date'] != null 
        ? DateTime.tryParse(json['graded_date'])
        : null,
      status: json['status'] ?? 'pending',
      submissionContent: json['submission_content'],
      files: (json['files'] as List<dynamic>?)
          ?.map((e) => AssignmentFileModel.fromJson(e))
          .toList() ?? [],
      grade: json['grade']?.toDouble(),
      passingGrade: (json['passing_grade'] ?? 65).toDouble(),
      pointsEarned: json['points_earned'] ?? 0,
      pointsPossible: json['points_possible'] ?? 100,
      instructorFeedback: json['instructor_feedback'],
      gradedBy: json['graded_by'],
      gradedByName: json['graded_by_name'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignment_id': assignmentId,
      'student_id': studentId,
      'course_id': courseId,
      'lesson_id': lessonId,
      'attempt': attemptNumber,
      'submitted_date': submittedDate.toIso8601String(),
      'graded_date': gradedDate?.toIso8601String(),
      'status': status,
      'submission_content': submissionContent,
      'files': files.map((e) => e.toJson()).toList(),
      'grade': grade,
      'passing_grade': passingGrade,
      'points_earned': pointsEarned,
      'points_possible': pointsPossible,
      'instructor_feedback': instructorFeedback,
      'graded_by': gradedBy,
      'graded_by_name': gradedByName,
    };
  }
  
  bool get isGraded => status == 'graded' || status == 'passed' || status == 'failed';
  bool get isPassed => status == 'passed' || (grade != null && grade! >= passingGrade);
  bool get isPending => status == 'pending';
  bool get hasFiles => files.isNotEmpty;
  bool get hasFeedback => instructorFeedback != null && instructorFeedback!.isNotEmpty;
  double get gradePercentage => pointsPossible > 0 
    ? (pointsEarned / pointsPossible * 100) 
    : 0;
}

class AssignmentFileModel {
  final int id;
  final String fileName;
  final String fileUrl;
  final String fileType;
  final int fileSize;
  final DateTime uploadedDate;
  
  AssignmentFileModel({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.uploadedDate,
  });
  
  factory AssignmentFileModel.fromJson(Map<String, dynamic> json) {
    return AssignmentFileModel(
      id: json['id'] ?? 0,
      fileName: json['file_name'] ?? '',
      fileUrl: json['file_url'] ?? '',
      fileType: json['file_type'] ?? '',
      fileSize: json['file_size'] ?? 0,
      uploadedDate: DateTime.parse(json['uploaded_date'] ?? DateTime.now().toIso8601String()),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_name': fileName,
      'file_url': fileUrl,
      'file_type': fileType,
      'file_size': fileSize,
      'uploaded_date': uploadedDate.toIso8601String(),
    };
  }
  
  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1048576) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / 1048576).toStringAsFixed(1)} MB';
  }
}