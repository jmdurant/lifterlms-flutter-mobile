import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/controller/lifterlms/review_controller.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({Key? key}) : super(key: key);

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget renderItem({item}) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(width: 1, color: Color(0xFFEBEBEB)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(item['display_name'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'poppins',
                        color: Colors.grey.shade700)),
              ),
              RatingBar.builder(
                ignoreGestures: true,
                initialRating: double.parse(item['rate']),
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemSize: 12,
                unratedColor: Colors.grey,
                itemBuilder: (context, _) => Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: (rating) {
                  // Đây là nơi bạn có thể xử lý khi người dùng đánh giá.
                },
              ),
            ],
          ),
          SizedBox(
            height: 8,
          ),
          Text(
            item['title'],
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'medium',
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(
            height: 8,
          ),
          Text(
            item['content'],
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'poppins',

            ),
          ),
          SizedBox(
            height: 8,
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery.of(context).size.width;
    return GetBuilder<ReviewController>(builder: (value) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        drawerEnableOpenDragGesture: false,
        body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Container(
                  height: 80.0,
                  width: screenWidth,
                  // color: Colors.blue,
                  padding: const EdgeInsets.fromLTRB(0, 40, 0, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      IconButton(
                          onPressed: () {
                            Get.back();
                          },
                          icon: const Icon(Icons.arrow_back),
                          color: Colors.grey[900],
                          iconSize: 24,
                        ),
                      Text(
                        tr( LocaleKeys.reviews_title),
                        style: const TextStyle(
                          fontFamily: 'Poppins-Medium',
                          fontWeight: FontWeight.w500,
                          fontSize: 24,
                        ),
                      ),
                      Container(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => value.loadReviews(),
                    child: ListView.builder(
                        controller: value.scrollController,
                        itemCount: value.reviews.length +
                            (value.isLoading.value ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == value.reviews.length) {
                            return const Center(
                                child: SizedBox(
                              width: 20.0,
                              height: 20.0,
                              child: CircularProgressIndicator(),
                            ));
                          } else if (index < value.reviews.length) {
                            return renderItem(item: value.reviews[index]);
                          } else {
                            return Container();
                          }
                        }),
                  ),
                ),
              ],
            ),
      );
    });
  }
}
