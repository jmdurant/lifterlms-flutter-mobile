import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/helper/function_helper.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';

class ItemMyCourse extends StatelessWidget {
  final LLMSCourseModel item;
  final double progress;
  final String enrollmentDate;
  final VoidCallback? onContinue;
  final VoidCallback? onDetail;

  ItemMyCourse({
    super.key, 
    required this.item,
    this.progress = 0.0,
    this.enrollmentDate = '',
    this.onContinue,
    this.onDetail,
  });

  var screenWidth =
      (window.physicalSize.shortestSide / window.devicePixelRatio);

  @override
  Widget build(BuildContext context) {
    // Calculate progress bar width
    double progressWidth = (progress / 100) * (screenWidth - 132);
    
    // Determine status color and text
    Color statusColor;
    String statusText;
    
    if (progress >= 100) {
      statusColor = const Color(0xFF56C943);
      statusText = tr(LocaleKeys.myCourse_filters_passed);
    } else if (progress > 0) {
      statusColor = const Color(0xFF58C3FF);
      statusText = tr(LocaleKeys.myCourse_filters_inProgress);
    } else {
      statusColor = const Color(0xFF939393);
      statusText = 'Not Started';
    }
    
    return GestureDetector(
        onTap: onDetail ?? () {},
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: item.featuredImage.isNotEmpty && 
                             !item.featuredImage.contains('placeholder')
                          ? NetworkImage(item.featuredImage)
                          : Image.asset("assets/images/placeholder-500x300.png").image,
                    ),
                  ),
                ),
                Container(
                  width: screenWidth - 100 - 32,
                  constraints: BoxConstraints(minHeight: 100),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Categories display removed - only have category IDs in LifterLMS model
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          item.title,
                          maxLines: 1,
                          style: const TextStyle(
                            fontFamily: "medium",
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: screenWidth - 100 - 32,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F3F3),
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Stack(
                          children: [
                            // Progress bar
                            Container(
                              width: progressWidth,
                              decoration: BoxDecoration(
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                        fontFamily: "Poppins",
                                        fontSize: 12,
                                        color: statusColor),
                                  ),
                                  if (progress > 0 && progress < 100)
                                    Text(
                                      ' (${progress.toStringAsFixed(0)}%)',
                                      style: TextStyle(
                                          fontFamily: "Poppins",
                                          fontSize: 12,
                                          color: statusColor),
                                    ),
                                ],
                              ),
                              if (enrollmentDate.isNotEmpty)
                                Text(
                                  enrollmentDate,
                                  style: const TextStyle(
                                      fontSize: 10, color: Color(0xFF939393)),
                                ),
                            ]),
                      ),
                      if (onContinue != null && progress > 0 && progress < 100)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          child: GestureDetector(
                            onTap: onContinue,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Continue Learning',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontFamily: "Poppins",
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            )));
  }
}