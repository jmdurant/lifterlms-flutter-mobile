import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/mobx-store/wishlist_store.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/controller/lifterlms/courses_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/home_controller.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:get/get.dart';
// import 'package:watch_it/watch_it.dart';

class TopCourse extends StatelessWidget {
  final List<LLMSCourseModel> topCoursesList;

  TopCourse({super.key, required this.topCoursesList});

  void onNavigate() {}
  final HomeController _controller = Get.find();
  
  String _formatPrice(double price) {
    if (price == 0) return tr(LocaleKeys.free);
    return "\$${price.toStringAsFixed(2)}";
  }

  @override
  Widget build(BuildContext context) {
    final CoursesController courseController = Get.find<CoursesController>();
    final WishlistStore wishlistStore = Get.find<WishlistStore>();
    
    // Determine if we should use grid or horizontal scroll based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final bool useGrid = screenWidth < 600; // Use grid for phones/narrow screens
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.only(
            left: 16,
          ),
          child: Text(
            tr(LocaleKeys.home_popular),
            style: const TextStyle(
              fontFamily: "semibold",
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 17),
        useGrid
            ? _buildGridView(context, courseController, wishlistStore)
            : _buildHorizontalScrollView(courseController, wishlistStore),
      ],
    );
  }
  
  Widget _buildGridView(BuildContext context, CoursesController courseController, WishlistStore wishlistStore) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 48) / 2; // 2 columns with padding
    
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 0),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85, // Better aspect ratio for course cards
        ),
        itemCount: topCoursesList.length,
        itemBuilder: (context, index) {
          return _buildCourseCard(index, courseController, wishlistStore, itemWidth);
        },
      ),
    );
  }
  
  Widget _buildHorizontalScrollView(CoursesController courseController, WishlistStore wishlistStore) {
    return Container(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Wrap(
                // spacing: 8,
                direction: Axis.horizontal,
                children: List.generate(
                  topCoursesList.length,
                  (index) => Container(
                    width: 220,
                    padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
                    child: _buildCourseCard(index, courseController, wishlistStore, 220),
                  ),
                )),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCourseImageStack(int index, CoursesController courseController, WishlistStore wishlistStore, double width) {
    return Stack(
      children: [
        Container(
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              fit: BoxFit.cover,
              image: topCoursesList[index].featuredImage.isNotEmpty &&
                      !topCoursesList[index].featuredImage.contains('placeholder')
                  ? NetworkImage(topCoursesList[index].featuredImage)
                  : Image.asset("assets/images/placeholder-500x300.png").image,
            ),
          ),
        ),
        topCoursesList[index].onSale
                      ? Positioned(
                          top: 10,
                          left: 15,
                          child: Container(
                            width: 49,
                            height: 21,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBC815),
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                tr(LocaleKeys.sale),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(),
                  Positioned(
                    top: 10,
                    right: 15,
                    child: wishlistStore.data.any((element) =>
                                element.id ==
                                topCoursesList[index].id) ==
                            true
                        ? GestureDetector(
                            onTap: () async => {
                                  await _controller
                                      .onToggleWishlist(
                                          topCoursesList[
                                              index]),
                                  courseController
                                      .refreshScreen(),
                                },
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.amber,
                              size: 22,
                            ))
                        : GestureDetector(
                            onTap: () async => {
                                  await _controller
                                      .onToggleWishlist(
                                          topCoursesList[
                                              index]),
                                  courseController
                                      .refreshScreen(),
                                },
                            child: const Icon(
                              Icons.favorite_border,
                              color: Colors.white,
                              size: 22,
                            )),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: width,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: topCoursesList[index].onSale
                                ? Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      color: Colors.white,
                                    ),
                                    child: Wrap(
                                      direction: Axis.horizontal,
                                      children: [
                                        Text(
                                          _formatPrice(topCoursesList[index].salePrice),
                                          style: const TextStyle(
                                            fontFamily: 'semibold',
                                            fontSize: 10,
                                            color: Colors.black,
                                            fontWeight:
                                                FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 5,
                                        ),
                                        Text(
                                          _formatPrice(topCoursesList[index].regularPrice),
                                          style: const TextStyle(
                                            fontFamily: 'semibold',
                                            fontSize: 10,
                                            color: Colors.black45,
                                            fontWeight:
                                                FontWeight.w500,
                                            decoration:
                                                TextDecoration
                                                    .lineThrough,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : topCoursesList[index].price > 0
                                    ? Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          color: Colors.white,
                                        ),
                                        child: Text(
                                          _formatPrice(topCoursesList[index].price),
                                          style: TextStyle(
                                              fontFamily: 'semibold',
                                              fontSize: 10),
                                        ),
                                      )
                                    : Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          color: Colors.white,
                                        ),
                                        child: Text(
                                          tr(LocaleKeys.free),
                                          style: const TextStyle(
                                            fontFamily: 'semibold',
                                            fontSize: 10,
                                            color: Colors.black,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                          ),
                          if (topCoursesList[index].averageRating > 0)
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 15,
                                ),
                                Text(
                                  topCoursesList[index]
                                      .averageRating
                                      .toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontFamily: 'semibold',
                                    fontWeight:
                                        FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
      ],
    );
  }
  
  Widget _buildCourseCard(int index, CoursesController courseController, WishlistStore wishlistStore, double width) {
    final bool isGridView = width < 220; // Check if this is for grid view
    
    return GestureDetector(
        onTap: () => {
              Get.toNamed(AppRouter.getCourseDetailRoute(),
                  arguments: {'id': topCoursesList[index].id})
            },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isGridView 
                ? Expanded(
                    child: _buildCourseImageStack(index, courseController, wishlistStore, width),
                  )
                : SizedBox(
                    height: 134,
                    child: _buildCourseImageStack(index, courseController, wishlistStore, width),
                  ),
            const SizedBox(height: 10),
            Text(
              topCoursesList[index].title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'semibold',
                  fontSize: 12,
                  fontWeight: FontWeight.w400),
            ),
          ],
        ));
  }
}