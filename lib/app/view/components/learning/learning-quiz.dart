import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/mobx-store/course_store.dart';
import 'package:flutter_app/app/backend/mobx-store/init_store.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_lesson_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_quiz_model.dart';
import 'package:flutter_app/app/controller/lifterlms/learning_controller.dart';
import 'package:flutter_app/app/helper/function_helper.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:watch_it/watch_it.dart';

class LearningQuiz extends WatchingWidget {
  final LLMSLessonModel data;
  final LLMSQuizModel dataQuiz;

  LearningQuiz({super.key, required this.data, required this.dataQuiz});

  final courseStore = locator<CourseStore>();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LearningController>(builder: (value) {
      return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  // crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 22,
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Text(
                      dataQuiz.timeLimit > 0 
                        ? "${dataQuiz.timeLimit} minutes"
                        : "No time limit",
                      style: TextStyle(color: Colors.red[500]),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 8,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  dataQuiz.title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500),
                ),
              ),
              SizedBox(
                height: 8,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(tr(
                      LocaleKeys.learningScreen_quiz_questionCount,
                    )),
                    Text(
                      dataQuiz.totalQuestions.toString(),
                    )
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(tr(
                      LocaleKeys.learningScreen_quiz_passingGrade,
                    )),
                    Text(
                      "${dataQuiz.passingPercentage}%",
                    )
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.all(16),
                child: HtmlWidget(
                  dataQuiz.content,
                  textStyle: TextStyle(
                    // padding: const EdgeInsets.symmetric(horizontal: 8),
                    fontFamily: 'Poppins-ExtraLight',
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                    0xFF36CE61,
                  )),
                  onPressed: () => value.startQuiz(),
                  child: Text(
                    tr(
                      LocaleKeys.learningScreen_quiz_btnStart,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ));
    });
  }
}
