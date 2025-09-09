import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

class QuizQuestionWidget extends StatefulWidget {
  final Map<String, dynamic> question;
  final Function(dynamic) onAnswerChanged;
  final dynamic currentAnswer;
  
  const QuizQuestionWidget({
    Key? key,
    required this.question,
    required this.onAnswerChanged,
    this.currentAnswer,
  }) : super(key: key);
  
  @override
  State<QuizQuestionWidget> createState() => _QuizQuestionWidgetState();
}

class _QuizQuestionWidgetState extends State<QuizQuestionWidget> {
  late dynamic _answer;
  TextEditingController? _blankController;
  
  // Helper function to decode HTML entities
  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#8217;', "'")
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"')
        .replaceAll('&#8211;', '–')
        .replaceAll('&#8212;', '—')
        .replaceAll('&#8230;', '...')
        .replaceAll('&nbsp;', ' ');
  }
  
  @override
  void initState() {
    super.initState();
    _answer = widget.currentAnswer;
    
    // Initialize controller for blank questions
    if (widget.question['type'] == 'blank') {
      _blankController = TextEditingController(text: widget.currentAnswer?.toString() ?? '');
    }
    
    print('QuizQuestionWidget.initState - Question ${widget.question['id']}: ${widget.question['title']}');
    print('QuizQuestionWidget.initState - Question type: ${widget.question['type']}');
    print('QuizQuestionWidget.initState - Current answer: ${widget.currentAnswer}');
    print('QuizQuestionWidget.initState - Current answer type: ${widget.currentAnswer?.runtimeType}');
    print('QuizQuestionWidget.initState - _answer initialized to: $_answer');
  }
  
  @override
  void dispose() {
    _blankController?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final String type = widget.question['type'] ?? '';
    final String title = _decodeHtmlEntities(widget.question['title'] ?? '');
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.question['content'] != null && widget.question['content'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: HtmlWidget(widget.question['content']),
              ),
            const SizedBox(height: 16),
            
            // Question Type Specific Widget
            _buildQuestionWidget(type),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuestionWidget(String type) {
    switch (type) {
      case 'choice':
        return _buildMultipleChoice();
      case 'true_false':
        return _buildTrueFalse();
      case 'picture_choice':
        return _buildPictureChoice();
      case 'blank':
      case 'fill_in_the_blank':
        return _buildFillInBlank();
      case 'reorder':
        return _buildReorder();
      case 'scale':
        return _buildScale();
      default:
        return Text('Unsupported question type: $type');
    }
  }
  
  Widget _buildMultipleChoice() {
    final choices = widget.question['choices'] as List? ?? [];
    
    return Column(
      children: choices.map((choice) {
        final String id = choice['id'].toString();
        final String text = _decodeHtmlEntities(choice['choice'] ?? '');
        final String marker = choice['marker'] ?? '';
        
        return RadioListTile<String>(
          title: Text('$marker. $text'),
          value: id,
          groupValue: _answer,
          onChanged: (value) {
            setState(() {
              _answer = value;
            });
            widget.onAnswerChanged(value);
          },
        );
      }).toList(),
    );
  }
  
  Widget _buildTrueFalse() {
    final choices = widget.question['choices'] as List? ?? [];
    
    return Row(
      children: choices.map((choice) {
        final String id = choice['id'].toString();
        final String text = _decodeHtmlEntities(choice['choice'] ?? '');
        
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _answer = id;
                });
                widget.onAnswerChanged(id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _answer == id ? Colors.blue : Colors.grey.shade300,
                foregroundColor: _answer == id ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(text, style: const TextStyle(fontSize: 16)),
            ),
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildPictureChoice() {
    final choices = widget.question['choices'] as List? ?? [];
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: choices.length,
      itemBuilder: (context, index) {
        final choice = choices[index];
        final String id = choice['id'].toString();
        final String marker = choice['marker'] ?? '';
        final image = choice['image'] ?? choice['choice'];
        final String imageUrl = image is Map ? (image['src'] ?? '') : '';
        
        return InkWell(
          onTap: () {
            setState(() {
              _answer = id;
            });
            widget.onAnswerChanged(id);
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _answer == id ? Colors.blue : Colors.grey.shade300,
                width: _answer == id ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Expanded(
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.error);
                          },
                        )
                      : const Icon(Icons.image, size: 50),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: _answer == id ? Colors.blue : Colors.grey.shade200,
                  child: Text(
                    marker,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _answer == id ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFillInBlank() {
    final Map<String, dynamic> blankData = widget.question['choices'] ?? {};
    final int blankCount = blankData['blank_count'] ?? 1;
    
    // For single blank, use string; for multiple, use list
    if (blankCount == 1) {
      return TextField(
        decoration: const InputDecoration(
          labelText: 'Your Answer',
          border: OutlineInputBorder(),
        ),
        controller: _blankController,  // Use persistent controller
        onChanged: (value) {
          setState(() {
            _answer = value;
          });
          widget.onAnswerChanged(value);
        },
      );
    } else {
      // Multiple blanks - use a list
      if (_answer == null || _answer is! List) {
        _answer = List.filled(blankCount, '');
      }
      
      return Column(
        children: List.generate(blankCount, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Blank ${index + 1}',
                border: const OutlineInputBorder(),
              ),
              controller: TextEditingController(
                text: (_answer as List)[index]?.toString() ?? ''
              ),
              onChanged: (value) {
                (_answer as List)[index] = value;
                // For API submission, join multiple blanks with comma
                final answerString = (_answer as List).join(',');
                widget.onAnswerChanged(answerString);
              },
            ),
          );
        }),
      );
    }
  }
  
  Widget _buildReorder() {
    List<Map<String, dynamic>> choices = 
        List<Map<String, dynamic>>.from(widget.question['choices'] ?? []);
    
    // Initialize answer with current order if not set or if it's not a list
    if (_answer == null || _answer is! List) {
      _answer = choices.map((c) => c['id']).toList();
    }
    
    // Build choices map for easy lookup
    final choicesMap = {for (var c in choices) c['id']: c};
    
    // Build list based on current answer order (safe cast now)
    final List<dynamic> answerList = _answer as List<dynamic>;
    final orderedItems = answerList.map((id) {
      final choice = choicesMap[id];
      if (choice == null) return null;
      return choice;
    }).whereType<Map<String, dynamic>>().toList();
    
    // Simple approach with up/down buttons
    return Column(
      children: List.generate(orderedItems.length, (index) {
        final choice = orderedItems[index];
        final String text = _decodeHtmlEntities(choice['choice'] ?? '');
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (index > 0)
                  InkWell(
                    onTap: () {
                      setState(() {
                        final List<dynamic> items = List.from(_answer);
                        final item = items.removeAt(index);
                        items.insert(index - 1, item);
                        _answer = items;
                      });
                      widget.onAnswerChanged(_answer);
                    },
                    child: const Icon(Icons.arrow_upward, size: 20),
                  ),
                if (index < orderedItems.length - 1)
                  InkWell(
                    onTap: () {
                      setState(() {
                        final List<dynamic> items = List.from(_answer);
                        final item = items.removeAt(index);
                        items.insert(index + 1, item);
                        _answer = items;
                      });
                      widget.onAnswerChanged(_answer);
                    },
                    child: const Icon(Icons.arrow_downward, size: 20),
                  ),
              ],
            ),
            title: Text(text),
            trailing: Text('${index + 1}', 
              style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      }),
    );
  }
  
  Widget _buildScale() {
    final Map<String, dynamic> scaleData = widget.question['choices'] ?? {};
    final double min = (scaleData['min'] ?? 1).toDouble();
    final double max = (scaleData['max'] ?? 10).toDouble();
    final String minLabel = _decodeHtmlEntities(scaleData['min_label'] ?? '');
    final String maxLabel = _decodeHtmlEntities(scaleData['max_label'] ?? '');
    
    // Parse answer safely - it might be a string, int, double, or wrongly a List
    double currentValue = min;
    if (_answer != null) {
      if (_answer is num) {
        currentValue = _answer.toDouble();
      } else if (_answer is String) {
        // Try to parse as number, otherwise use min
        currentValue = double.tryParse(_answer) ?? min;
      } else if (_answer is List) {
        // Wrong type - shouldn't happen but handle gracefully
        print('WARNING: Scale widget received List answer: $_answer');
        currentValue = min;
      }
    }
    
    // Ensure value is within range
    currentValue = currentValue.clamp(min, max);
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (minLabel.isNotEmpty) Text(minLabel),
            Text(
              currentValue.toInt().toString(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (maxLabel.isNotEmpty) Text(maxLabel),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: currentValue,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          label: currentValue.toInt().toString(),
          onChanged: (value) {
            setState(() {
              _answer = value.toInt().toString();
            });
            widget.onAnswerChanged(_answer);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(min.toInt().toString()),
            Text(max.toInt().toString()),
          ],
        ),
      ],
    );
  }
}