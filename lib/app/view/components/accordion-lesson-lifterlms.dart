import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_section_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_lesson_model.dart';
import 'package:flutter_app/app/view/components/item-lesson.dart';
import 'package:get/get.dart';

import '../../controller/lifterlms/course_detail_controller.dart';

typedef OnNavigateCallback = void Function(dynamic item);

class AccordionLessonLifterLMS extends StatefulWidget {
  final List<LLMSSectionModel>? data;
  final int indexLesson;
  final OnNavigateCallback onNavigate;
  
  const AccordionLessonLifterLMS({
    Key? key, 
    required this.data, 
    required this.indexLesson, 
    required this.onNavigate
  }) : super(key: key);
  
  @override
  State<AccordionLessonLifterLMS> createState() => _AccordionLifterLMSState();
}

class _AccordionLifterLMSState extends State<AccordionLessonLifterLMS> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  var screenWidth = (window.physicalSize.shortestSide / window.devicePixelRatio);
  
  @override
  Widget build(BuildContext context) {
    CourseDetailController value = Get.find();
    
    if (widget.data == null || widget.data!.isEmpty) {
      return const Center(
        child: Text('No sections available'),
      );
    }
    
    return SizedBox(
      width: double.infinity,
      child: Flex(
        direction: Axis.vertical,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(widget.data!.length,
              (index) => SizedBox(
                width: double.infinity,
                child: AccordionItemLessonLifterLMS(
                  section: widget.data![index],
                  onNavigate: (item) => {
                    widget.onNavigate(item),
                  },
                  showContent: widget.indexLesson == index,
                ),
              )
            )
          ),
        ],
      ),
    );
  }
}

class AccordionItemLessonLifterLMS extends StatefulWidget {
  final LLMSSectionModel section;
  final bool showContent;
  final OnNavigateCallback onNavigate;
  
  const AccordionItemLessonLifterLMS({
    Key? key,
    required this.section,
    required this.showContent,
    required this.onNavigate,
  }) : super(key: key);
  
  @override
  State<AccordionItemLessonLifterLMS> createState() => _AccordionItemLessonLifterLMSState();
}

class _AccordionItemLessonLifterLMSState extends State<AccordionItemLessonLifterLMS> {
  late bool _showContent;
  var screenWidth = (window.physicalSize.shortestSide / window.devicePixelRatio);
  
  @override
  void initState() {
    super.initState();
    _showContent = widget.showContent;
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showContent = !_showContent;
              });
              // If expanding and lessons are not loaded yet, load on demand via controller
              if (_showContent && widget.section.lessons.isEmpty) {
                try {
                  final ctrl = Get.find<CourseDetailController>();
                  ctrl.loadSectionOnDemand(widget.section.id);
                } catch (_) {}
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.section.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Section ${widget.section.order}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _showContent ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[700],
                  ),
                ],
              ),
            ),
          ),
          if (_showContent && widget.section.lessons.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: widget.section.lessons.map((lesson) {
                  return GestureDetector(
                    onTap: () => widget.onNavigate(lesson),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            lesson.hasQuiz ? Icons.quiz_outlined :
                            lesson.requiresAssignment ? Icons.assignment_outlined :
                            Icons.article_outlined,
                            size: 20,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lesson.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (lesson.points > 0)
                                  Text(
                                    '${lesson.points} points',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (lesson.isCompleted)
                            const Icon(
                              Icons.check_circle,
                              size: 20,
                              color: Colors.green,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
