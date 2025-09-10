import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_app/app/controller/lifterlms/learning_controller.dart';
import 'package:flutter_app/app/view/components/quiz/quiz_question_widget.dart';

class QuizTakingScreen extends StatefulWidget {
  const QuizTakingScreen({Key? key}) : super(key: key);
  
  @override
  State<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<QuizTakingScreen> {
  final LearningController controller = Get.find<LearningController>();
  
  int currentQuestionIndex = 0;
  Map<int, dynamic> answers = {};
  List<Map<String, dynamic>> questions = [];
  int? attemptId;
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _startQuizAttempt();
  }
  
  Future<void> _startQuizAttempt() async {
    final quiz = controller.currentQuiz.value;
    final lesson = controller.currentLesson.value;
    
    if (quiz == null || lesson == null) {
      Get.back();
      return;
    }
    
    try {
      // Start the quiz attempt
      final response = await controller.lmsService.api.startQuizAttempt(
        quizId: quiz.id,
        lessonId: lesson.id,
      );
      
      if (response.statusCode == 200) {
        try {
          final data = response.body;
          print('Got response data: ${data.runtimeType}');
          
          setState(() {
            // Convert attempt_id to int if it's a string
            final attemptIdValue = data['attempt_id'];
            if (attemptIdValue is String) {
              attemptId = int.tryParse(attemptIdValue);
            } else {
              attemptId = attemptIdValue as int?;
            }
            questions = List<Map<String, dynamic>>.from(data['questions'] ?? []);
            isLoading = false;
          });
          
          print('Quiz loaded - attemptId: $attemptId, questions: ${questions.length}');
          
          // Initialize timer if needed
          if (data['time_limit'] != null && data['time_limit'] > 0) {
            _startTimer(data['time_limit'] * 60);
          }
        } catch (e, stackTrace) {
          print('ERROR parsing quiz response: $e');
          print('Stack trace: $stackTrace');
          setState(() {
            isLoading = false;
          });
          Get.snackbar('Error', 'Failed to load quiz: $e');
        }
      } else {
        Get.snackbar('Error', 'Failed to start quiz');
        Get.back();
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to start quiz: $e');
      Get.back();
    }
  }
  
  void _startTimer(int seconds) {
    // TODO: Implement countdown timer
  }
  
  void _onAnswerChanged(int questionId, dynamic answer) {
    print('Answer changed for question $questionId: $answer');
    print('Current answers map: $answers');
    setState(() {
      answers[questionId] = answer;
    });
    print('Updated answers map: $answers');
  }
  
  void _nextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      final nextQuestion = questions[currentQuestionIndex + 1];
      print('Moving to next question: ${nextQuestion['id']} - ${nextQuestion['title']}');
      print('Current answer for next question: ${answers[nextQuestion['id']]}');
      setState(() {
        currentQuestionIndex++;
      });
    }
  }
  
  void _previousQuestion() {
    if (currentQuestionIndex > 0) {
      final prevQuestion = questions[currentQuestionIndex - 1];
      print('Moving to previous question: ${prevQuestion['id']} - ${prevQuestion['title']}');
      print('Current answer for previous question: ${answers[prevQuestion['id']]}');
      setState(() {
        currentQuestionIndex--;
      });
    }
  }
  
  Future<void> _submitQuiz() async {
    print('Submit quiz called - attemptId: $attemptId');
    
    // Check if we have an attempt ID
    if (attemptId == null) {
      print('ERROR: attemptId is null, cannot submit');
      Get.snackbar('Error', 'Quiz attempt not initialized properly');
      return;
    }
    
    print('Showing confirmation dialog...');
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Quiz?'),
        content: Text('You have answered ${answers.length} out of ${questions.length} questions. Are you sure you want to submit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    
    if (confirm != true) {
      print('User cancelled submission');
      return;
    }
    
    print('Submitting quiz with ${answers.length} answers out of ${questions.length} questions...');
    
    // Submit each answer one by one (including unanswered as empty)
    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final questionId = question['id'];
      final answer = answers[questionId];
      
      // Submit even if answer is null (unanswered)
      print('Submitting answer for question $questionId: ${answer ?? "(unanswered)"}');
      print('Question type: ${question['type']}');
      try {
        // Format answer based on question type - MUST match API expectations
        dynamic submissionAnswer = answer ?? '';
        
        // Multiple choice, picture choice, and true/false need array format
        if (question['type'] == 'choice' || 
            question['type'] == 'picture_choice' || 
            question['type'] == 'true_false') {
          if (answer != null && answer is! List) {
            // Convert single answer to array
            submissionAnswer = [answer.toString()];
            print('Converted ${question['type']} answer to array: $submissionAnswer');
          } else if (answer is List) {
            // Already an array, ensure all elements are strings
            submissionAnswer = (answer as List).map((e) => e.toString()).toList();
            print('Kept ${question['type']} answer as array: $submissionAnswer');
          } else {
            // No answer - send empty array
            submissionAnswer = [];
            print('No answer for ${question['type']}, sending empty array');
          }
        }
        // Reorder questions need comma-separated string
        else if (question['type'] == 'reorder') {
          if (answer is List) {
            submissionAnswer = (answer as List).join(',');
            print('Converted reorder answer to comma-separated string: $submissionAnswer');
          } else if (answer != null) {
            submissionAnswer = answer.toString();
            print('Reorder answer already string: $submissionAnswer');
          } else {
            // No answer means user didn't reorder - send the original order
            final choices = question['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              submissionAnswer = choices.map((choice) => 
                choice is Map ? choice['id'] : choice
              ).join(',');
              print('Reorder not changed, sending original order: $submissionAnswer');
            } else {
              submissionAnswer = '';
              print('No reorder choices available');
            }
          }
        }
        // Scale questions need array format with string value
        else if (question['type'] == 'scale') {
          if (answer != null) {
            submissionAnswer = [answer.toString()];
            print('Converted scale answer to array: $submissionAnswer');
          } else {
            submissionAnswer = [];
            print('No scale answer, sending empty array');
          }
        }
        // Blank/fill-in-the-blank questions
        else if (question['type'] == 'blank' || question['type'] == 'fill_in_the_blank') {
          if (answer != null) {
            // Check if multiple blanks (answer would be comma-separated)
            if (answer is List) {
              submissionAnswer = (answer as List).join(',');
              print('Converted multiple blanks to comma-separated: $submissionAnswer');
            } else {
              // Single blank - send as array
              submissionAnswer = [answer.toString()];
              print('Converted blank answer to array: $submissionAnswer');
            }
          } else {
            submissionAnswer = [''];
            print('No blank answer, sending empty array');
          }
        }
        // Default for other types (short_answer, long_answer, etc.)
        else {
          if (answer != null) {
            submissionAnswer = answer.toString();
            print('Using string format for ${question['type']}: $submissionAnswer');
          }
        }
        
        print('Final submission answer type: ${submissionAnswer.runtimeType}');
        print('Final submission answer value: $submissionAnswer');
        
        // Submit answer to API with attempt ID
        final result = await controller.lmsService.api.submitQuizAnswer(
          quizId: controller.currentQuiz.value!.id,
          questionId: questionId,
          answer: submissionAnswer,
          attemptId: attemptId,
        );
        print('Answer submission result: ${result.statusCode}');
        if (result.statusCode != 200) {
          print('Answer submission error: ${result.body}');
        }
      } catch (e) {
        print('ERROR submitting answer: $e');
      }
    }
    
    print('Finishing quiz...');
    try {
      // Complete the quiz
      final finishResult = await controller.lmsService.api.finishQuiz(
        quizId: controller.currentQuiz.value!.id,
        attemptId: attemptId!,
      );
      print('Finish quiz result: ${finishResult.statusCode}');
      if (finishResult.statusCode != 200) {
        print('Finish quiz error: ${finishResult.body}');
        Get.snackbar('Error', 'Quiz submission failed');
        Get.back();
      } else {
        // Parse the results
        final result = finishResult.body;
        print('Quiz results: $result');
        
        final bool passed = result['passed'] ?? false;
        // Use calculated_grade which is based on points, not the raw LifterLMS grade
        final double grade = (result['calculated_grade'] ?? result['grade'] ?? 0).toDouble();
        final int pointsEarned = result['points_earned'] ?? 0;
        final int pointsPossible = result['points_possible'] ?? 0;
        
        // Show results dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(passed ? 'Quiz Passed! 🎉' : 'Quiz Complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Grade: ${grade.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Points: $pointsEarned / $pointsPossible'),
                const SizedBox(height: 16),
                if (passed)
                  const Text('Great job! You passed the quiz.',
                    style: TextStyle(color: Colors.green))
                else
                  const Text('You can try again to improve your score.',
                    style: TextStyle(color: Colors.orange)),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              if (!passed)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Reset for retry
                    setState(() {
                      answers.clear();
                      currentQuestionIndex = 0;
                      isLoading = true;
                    });
                    _startQuizAttempt();
                  },
                  child: const Text('Try Again'),
                ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  
                  if (passed) {
                    // Mark lesson as complete
                    await controller.completeLesson();
                    
                    // Go back to learning screen
                    Get.back();
                    
                    // Auto-advance to next lesson if not already handled by completeLesson
                    if (!controller.autoAdvanceEnabled.value) {
                      await Future.delayed(const Duration(milliseconds: 500));
                      controller.navigateToNextLesson();
                    }
                  } else {
                    // Failed - just go back to the current lesson
                    Get.back();
                  }
                },
                child: Text(passed ? 'Continue to Next Lesson' : 'Back to Lesson'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('ERROR finishing quiz: $e');
      Get.snackbar('Error', 'Failed to submit quiz: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(
          child: Text('No questions available'),
        ),
      );
    }
    
    final currentQuestion = questions[currentQuestionIndex];
    final quiz = controller.currentQuiz.value!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(quiz.title),
        actions: [
          // Timer widget if needed
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Question ${currentQuestionIndex + 1} of ${questions.length}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (currentQuestionIndex + 1) / questions.length,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          
          // Question
          Expanded(
            child: SingleChildScrollView(
              child: QuizQuestionWidget(
                question: currentQuestion,
                currentAnswer: answers[currentQuestion['id']],
                onAnswerChanged: (answer) {
                  _onAnswerChanged(currentQuestion['id'], answer);
                },
              ),
            ),
          ),
          
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (currentQuestionIndex > 0)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _previousQuestion,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (currentQuestionIndex > 0) const SizedBox(width: 8),
                if (currentQuestionIndex < questions.length - 1)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _nextQuestion,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                      iconAlignment: IconAlignment.end,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (currentQuestionIndex == questions.length - 1)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _submitQuiz,
                      icon: const Icon(Icons.check),
                      label: const Text('Submit Quiz'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}