import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/mobx-store/course_store.dart';
import 'package:flutter_app/app/backend/mobx-store/init_store.dart';
import 'package:flutter_app/app/controller/lifterlms/learning_controller.dart';
import 'package:flutter_app/app/view/components/learning/learning-assignment.dart';
import 'package:flutter_app/app/view/components/learning/learning-lesson.dart';
import 'package:flutter_app/app/view/components/learning/learning-quiz.dart';
import 'package:flutter_app/app/view/components/learning/learning-start-quiz.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:get/get.dart';
import 'package:watch_it/watch_it.dart';
import 'package:indexed/indexed.dart';

class FinishLearningScreen extends WatchingStatefulWidget {
  FinishLearningScreen({Key? key}) : super(key: key);

  @override
  State<FinishLearningScreen> createState() => _FinishLearningState();
}

class _FinishLearningState extends State<FinishLearningScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final courseStore = locator<CourseStore>();
  var screenWidth =
      (window.physicalSize.shortestSide / window.devicePixelRatio);
  var screenHeight =
      (window.physicalSize.longestSide / window.devicePixelRatio);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LearningController>(builder: (value) {
      if (value.currentLesson.value == null && value.currentCourse.value == null) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.white,
          body: value.isLoading.value
              ? Center(child: CircularProgressIndicator())
              : Center(child: Text('No lesson data available')),
        );
      } else {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.white,
          drawerEnableOpenDragGesture: false,
          body: Stack(
            children: <Widget>[
              Indexed(
                index: 1,
                child: Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    width: screenWidth,
                    height: (209 / 375) * screenWidth,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).primaryColor.withOpacity(0.1),
                          Theme.of(context).primaryColor.withOpacity(0.05),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Column(children: <Widget>[
                Container(
                  height: 80.0,
                  width: screenWidth,
                  // color: Colors.blue,
                  padding: const EdgeInsets.fromLTRB(0, 30, 0, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        // width: 40,
                        child: IconButton(
                          onPressed: () {
                            Get.back();
                          },
                          icon: const Icon(Icons.menu),
                          color: Colors.grey[900],
                          iconSize: 24,
                        ),
                      ),
                      Container(
                        // width: 40,
                        child: IconButton(
                          onPressed: () {
                            Get.back();
                          },
                          icon: const Icon(Icons.close),
                          color: Colors.grey[900],
                          iconSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                    child: RefreshIndicator(
                        onRefresh: () => value.refreshData(),
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 100),
                            scrollDirection: Axis.vertical,
                            child: Container(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  // Show lesson content if it's a regular lesson
                                  if (value.currentLesson.value != null && 
                                      !value.currentLesson.value!.hasQuiz &&
                                      !value.currentLesson.value!.requiresAssignment)
                                    LearningLesson(
                                      data: value.currentLesson.value!,
                                    ),
                                  // Show quiz if lesson has quiz
                                  if (value.currentLesson.value != null &&
                                      value.currentLesson.value!.hasQuiz &&
                                      value.currentQuiz.value != null)
                                    LearningQuiz(
                                        data: value.currentLesson.value!,
                                        dataQuiz: value.currentQuiz.value!),
                                  // Show assignment if lesson requires assignment
                                  if (value.currentLesson.value != null &&
                                      value.currentLesson.value!.requiresAssignment)
                                    LearningAssignment(id: value.currentLesson.value!.id),
                                  // TODO: Handle quiz start state when implemented
                                  // Show course completion button if course is complete
                                  if (value.courseProgress.value >= 100)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 30),
                                      color: Colors.white,
                                      margin: const EdgeInsets.only(top: 30),
                                      child: GestureDetector(
                                        onTap: () => value.showCourseCompletionDialog(),
                                        child: Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF222222),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 21),
                                          height: 50,
                                          alignment: Alignment.center,
                                          child: Text(
                                            tr(
                                              LocaleKeys
                                                  .learningScreen_finishCourse,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                ]))))),
              ]),
            ],
          ),
        );
      }
    });
  }
}
