import 'package:easy_localization/easy_localization.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_instructor_model.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:get/get.dart';

import '../../helper/router.dart';

class Instructors extends StatelessWidget {
  final List<LLMSInstructorModel> instructorList;

  Instructors({super.key, required this.instructorList});

  void onNavigate(LLMSInstructorModel item) {
    print('Navigating to instructor: ${item.displayName} (ID: ${item.id})');
    Get.toNamed(AppRouter.getIntructorDetailRoute(), arguments: {'id': item.id});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),
        Container(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            tr(LocaleKeys.instructor),
            style: const TextStyle(
              fontFamily: "semibold",
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 25),
        Container(
          // height: 200,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Wrap(
                    direction: Axis.horizontal,
                    children: List.generate(
                      instructorList.length,
                      (index) => Container(
                          decoration: BoxDecoration(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(16))),
                          margin: const EdgeInsets.fromLTRB(16, 2, 0, 16),
                          // padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: GestureDetector(
                            onTap: () => onNavigate(instructorList[index]),
                            child: Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.5),
                                      spreadRadius: 1,
                                      blurRadius: 1,
                                      offset: const Offset(
                                          0, 1), // Thay đổi hướng đổ bóng
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    instructorList[index].avatarUrl.isNotEmpty
                                        ? Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(25),
                                                image: DecorationImage(
                                                  fit: BoxFit.cover,
                                                  image: NetworkImage(
                                                      instructorList[index]
                                                          .avatarUrl),
                                                )))
                                        : CircleAvatar(
                                            radius: 25,
                                            backgroundImage: Image.asset(
                                              'assets/images/default-avatar.png',
                                            ).image,
                                          ),
                                    SizedBox(
                                      width: 12,
                                    ),
                                    Container(
                                        child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(instructorList[index].name,
                                            style: const TextStyle(
                                                fontFamily: 'medium',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                overflow:
                                                    TextOverflow.ellipsis)),
                                        SizedBox(
                                          height: 4,
                                        ),
                                        Row(
                                          children: [
                                            if (instructorList[index].email.isNotEmpty) ...[
                                              Icon(
                                                FeatherIcons.send,
                                                size: 12,
                                                color: Colors.grey.shade500,
                                              ),
                                              SizedBox(width: 8),
                                            ],
                                            if (instructorList[index].social?['phone'] != null && 
                                                instructorList[index].social!['phone']!.isNotEmpty) ...[
                                              Icon(
                                                FeatherIcons.phoneCall,
                                                size: 12,
                                                color: Colors.grey.shade500,
                                              ),
                                              SizedBox(width: 8),
                                            ],
                                            if (instructorList[index].social?['instagram'] != null && 
                                                instructorList[index].social!['instagram']!.isNotEmpty) ...[
                                              Icon(
                                                FeatherIcons.instagram,
                                                size: 12,
                                                color: Colors.grey.shade500,
                                              ),
                                              SizedBox(width: 8),
                                            ],
                                            if (instructorList[index].social?['twitter'] != null && 
                                                instructorList[index].social!['twitter']!.isNotEmpty)
                                              Icon(
                                                FeatherIcons.twitter,
                                                size: 12,
                                                color: Colors.grey.shade500,
                                              ),
                                          ],
                                        )
                                      ],
                                    ))
                                  ],
                                )),
                          )),
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
