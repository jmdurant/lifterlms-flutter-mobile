import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/models/notification_model.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

import '../../helper/router.dart';

class ItemNotification extends StatelessWidget {
  final NotificationModel item;
  final VoidCallback? onDelete;

  ItemNotification({super.key, required this.item, this.onDelete});

  void onNavigate() {}
  var screenWidth =
      (window.physicalSize.shortestSide / window.devicePixelRatio);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: (){
          RegExp regExp = RegExp(r'\d+');
          Iterable<RegExpMatch> matches = regExp.allMatches(item.source??"");
          List<String> numbers = matches.map((match) => match.group(0)!).toList();
          if(numbers.isNotEmpty){
            Get.toNamed(AppRouter.getCourseDetailRoute(),arguments: {'id': int.parse(numbers[0])},preventDuplicates: false);
          }
        },
        child: Container(
            width: screenWidth - 32,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 1,
                  offset: const Offset(0, 1), // Thay đổi hướng đổ bóng
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  if (item.image != null &&
                      item.image != '' &&
                      item.image != 'null')
                    Container(
                        width: screenWidth,
                        height: (180 / 375) * screenWidth,
                        margin: EdgeInsetsDirectional.only(bottom: 20),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            image: DecorationImage(
                              fit: BoxFit.cover,
                              image: NetworkImage(item.image!),
                            ))),
                  if (item.title != null && item.title != '')

                    Text(
                      item.title!,
                      style:
                          TextStyle(fontWeight: FontWeight.w500, fontSize: 16,fontFamily: "medium"),
                    ),
                  SizedBox(height: 10,),
                  Text(
                    item.content!,
                    style: TextStyle(color: Colors.grey.shade700,fontFamily: "poppins"),
                  ),
                  SizedBox(height: 10,),
                  Text(
                    item.date_created!,
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color,fontFamily: "poppins"),
                  ),
                ]),
                if (onDelete != null)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                    ),
                  ),
              ],
            ))
    );
  }
}
