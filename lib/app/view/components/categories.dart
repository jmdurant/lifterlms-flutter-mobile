import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_category_model.dart';
import 'package:flutter_app/app/controller/lifterlms/courses_controller.dart';
import 'package:flutter_app/app/controller/tabs_controller.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class Categories extends StatelessWidget {
  final List<LLMSCategoryModel> categoriesList;
  final TabControllerX tabController = Get.find<TabControllerX>();
  final CoursesController courseController = Get.find<CoursesController>();
  Categories({super.key, required this.categoriesList});
  void onNavigate(LLMSCategoryModel category) {
    courseController.selectedCategoryId.value = category.id;
    courseController.getCourses(isRefresh: true);
    tabController.updateTabId(1);
  }

  List<Color> colors = [
    const Color(0xFFFFF1E1),
    const Color(0xFFE9FFE1),
    const Color(0xFFE1F3FF),
    const Color(0xFFE1E2FF),
    const Color(0xFFE1FFFD),
    const Color(0xFFF5E1FF),
    const Color(0xFFFFE1EC),
    const Color(0xFFFFF7E1)
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Container(
          // height: 200,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Wrap(
                    direction: Axis.horizontal,
                    children: List.generate(
                      categoriesList.length,
                      (index) => Container(
                        decoration: BoxDecoration(
                            color: colors[Random().nextInt(colors.length)],
                            borderRadius:
                                const BorderRadius.all(Radius.circular(16))),
                        margin: const EdgeInsets.fromLTRB(16, 0, 0, 0),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: GestureDetector(
                            onTap: () => onNavigate(categoriesList[index]),
                            child: Text(categoriesList[index].name,
                                style: const TextStyle(
                                  fontFamily: 'thin',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600
                                ))),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
