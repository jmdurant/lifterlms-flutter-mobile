import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_app/app/backend/api/lifterlms_api.dart';

class CmeEvaluationScreen extends StatefulWidget {
  final int courseId;
  final String courseTitle;

  const CmeEvaluationScreen({
    Key? key,
    required this.courseId,
    required this.courseTitle,
  }) : super(key: key);

  @override
  State<CmeEvaluationScreen> createState() => _CmeEvaluationScreenState();
}

class _CmeEvaluationScreenState extends State<CmeEvaluationScreen> {
  final LifterLMSApiService api = Get.find<LifterLMSApiService>();

  bool isLoading = true;
  bool isSubmitting = false;
  List<dynamic> questions = [];
  String disclosureText = '';
  Map<String, String> answers = {};

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final response =
        await api.getCmeEvaluationQuestions(courseId: widget.courseId);

    setState(() {
      isLoading = false;
      if (response.statusCode == 200) {
        final data = response.body;
        questions = data['questions'] ?? [];
        disclosureText = data['disclosure_text'] ?? '';
      }
    });
  }

  Future<void> _submitEvaluation() async {
    // Validate required questions
    for (final q in questions) {
      if (q['required'] == true && (answers[q['id']] ?? '').isEmpty) {
        Get.snackbar('Required', 'Please answer all required questions.');
        return;
      }
    }

    setState(() => isSubmitting = true);

    final responses = answers.entries
        .map((e) => {'question_id': e.key, 'answer': e.value})
        .toList();

    final response = await api.submitCmeEvaluation(
      courseId: widget.courseId,
      responses: responses,
    );

    setState(() => isSubmitting = false);

    if (response.statusCode == 200) {
      Get.back(result: true);
      Get.snackbar('Success', 'Evaluation submitted successfully.');
    } else {
      final msg = response.body is Map ? response.body['message'] : 'Submission failed';
      Get.snackbar('Error', msg ?? 'Submission failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post-Activity Evaluation'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : questions.isEmpty
              ? const Center(child: Text('No evaluation questions available.'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            widget.courseTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (disclosureText.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Disclosure',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(disclosureText),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          ...questions
                              .asMap()
                              .entries
                              .map((entry) => _buildQuestion(entry.key, entry.value)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.3),
                            blurRadius: 5,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : _submitEvaluation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Submit Evaluation',
                                  style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildQuestion(int index, dynamic question) {
    final id = question['id'] as String;
    final text = question['text'] as String;
    final type = question['type'] as String;
    final required = question['required'] == true;
    final options = (question['options'] as List?)?.cast<String>() ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${index + 1}. ',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(
                        text: text,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (required)
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildAnswerWidget(id, type, options),
        ],
      ),
    );
  }

  Widget _buildAnswerWidget(String id, String type, List<String> options) {
    switch (type) {
      case 'rating':
        return _buildRatingWidget(id, options);
      case 'yes_no':
        return _buildYesNoWidget(id);
      case 'multiple_choice':
        return _buildMultipleChoiceWidget(id, options);
      case 'text':
      default:
        return _buildTextWidget(id);
    }
  }

  Widget _buildRatingWidget(String id, List<String> options) {
    final labels = ['Strongly Disagree', '', 'Neutral', '', 'Strongly Agree'];
    final ratingOptions = options.isNotEmpty ? options : ['1', '2', '3', '4', '5'];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ratingOptions.map((option) {
            final selected = answers[id] == option;
            return GestureDetector(
              onTap: () => setState(() => answers[id] = option),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? Colors.blue : Colors.grey.shade200,
                    ),
                    child: Center(
                      child: Text(
                        option,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        if (ratingOptions.length == 5)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels
                .map((l) => SizedBox(
                      width: 60,
                      child: Text(l,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey)),
                    ))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildYesNoWidget(String id) {
    return Row(
      children: ['Yes', 'No'].map((option) {
        final selected = answers[id] == option.toLowerCase();
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ChoiceChip(
            label: Text(option),
            selected: selected,
            onSelected: (_) =>
                setState(() => answers[id] = option.toLowerCase()),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMultipleChoiceWidget(String id, List<String> options) {
    return Column(
      children: options.map((option) {
        final selected = answers[id] == option;
        return RadioListTile<String>(
          title: Text(option, style: const TextStyle(fontSize: 14)),
          value: option,
          groupValue: answers[id],
          onChanged: (value) => setState(() => answers[id] = value ?? ''),
          dense: true,
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }

  Widget _buildTextWidget(String id) {
    return TextField(
      decoration: const InputDecoration(
        hintText: 'Enter your response...',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.all(12),
      ),
      maxLines: 3,
      onChanged: (value) => answers[id] = value,
    );
  }
}
