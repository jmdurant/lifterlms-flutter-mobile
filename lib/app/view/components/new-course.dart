import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/mobx-store/wishlist_store.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/controller/lifterlms/home_controller.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:get/get.dart';
import 'package:watch_it/watch_it.dart';

class NewCourse extends WatchingWidget {
  final List<LLMSCourseModel> newCoursesList;

  NewCourse({super.key, required this.newCoursesList});

  final WishlistStore wishlistStore = Get.find<WishlistStore>();

  void onNavigate() {}
  
  String _formatPrice(double price) {
    if (price == 0) return tr(LocaleKeys.free);
    return "\$${price.toStringAsFixed(2)}";
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(builder: (value) {
      // Determine if we should use grid or horizontal scroll based on screen width
      final screenWidth = MediaQuery.of(context).size.width;
      final bool useGrid = screenWidth < 600; // Use grid for phones/narrow screens
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.only(
              left: 16,
            ),
            child: Text(
              tr(LocaleKeys.home_new),
              style: const TextStyle(
                fontFamily: "semibold",
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 25),
          useGrid
              ? _buildGridView(context, value)
              : _buildHorizontalScrollView(value),
        ],
      );
    });
  }
  
  Widget _buildGridView(BuildContext context, HomeController controller) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 48) / 2; // 2 columns with padding
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: itemWidth / (itemWidth * 1.3), // Adjust height ratio
        ),
        itemCount: newCoursesList.length,
        itemBuilder: (context, index) {
          return _buildCourseCard(index, controller, itemWidth);
        },
      ),
    );
  }
  
  Widget _buildHorizontalScrollView(HomeController controller) {
    return Container(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Wrap(
                // spacing: 8,
                direction: Axis.horizontal,
                children: List.generate(
                  newCoursesList.length,
                  (index) => Container(
                    width: 220,
                    padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
                    child: _buildCourseCard(index, controller, 220),
                  ),
                )),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCourseCard(int index, HomeController controller, double width) {
    return GestureDetector(
        onTap: () => {
              Get.toNamed(
                  AppRouter.getCourseDetailRoute(),
                  arguments: {'id': newCoursesList[index].id})
            },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.64, // 220/134 ratio
              child: Stack(
                children: [
                  Container(
                    width: width,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(8),
                      image: DecorationImage(
                        fit: BoxFit.cover,
                        image: newCoursesList[index]
                                .featuredImage.isNotEmpty &&
                                !newCoursesList[index]
                                .featuredImage
                                .contains('placeholder')
                            ? NetworkImage(
                                newCoursesList[index]
                                    .featuredImage)
                            : Image.asset(
                                    "assets/images/placeholder-500x300.png")
                                .image,
                      ),
                    ),
                  ),
                  newCoursesList[index].onSale
                      ? Positioned(
                          top: 10,
                          left: 15,
                          child: Container(
                            width: 49,
                            height: 21,
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFFFBC815),
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                tr(LocaleKeys.sale),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(),
                  Positioned(
                    top: 10,
                    right: 15,
                    child: wishlistStore.data.any(
                                (element) =>
                                    element.id ==
                                    newCoursesList[index]
                                        .id) ==
                            true
                        ? GestureDetector(
                            onTap: () => {
                                  controller.onToggleWishlist(
                                      newCoursesList[index])
                                },
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.amber,
                              size: 22,
                            ))
                        : GestureDetector(
                            onTap: () => {
                                  controller.onToggleWishlist(
                                      newCoursesList[index])
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
                            child: newCoursesList[index].onSale
                                ? Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                            horizontal: 8,
                                            vertical: 2),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(
                                              4),
                                      color: Colors.white,
                                    ),
                                    child: Wrap(
                                      direction:
                                          Axis.horizontal,
                                      children: [
                                        Text(
                                          _formatPrice(newCoursesList[index].salePrice),
                                          style:
                                              const TextStyle(
                                            fontFamily:
                                                'semibold',
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
                                          _formatPrice(newCoursesList[index].regularPrice),
                                          style:
                                              const TextStyle(
                                            fontFamily:
                                                'semibold',
                                            fontSize: 10,
                                            color:
                                                Colors.black45,
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
                                : newCoursesList[index].price > 0
                                    ? Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 8,
                                            vertical: 2),
                                        decoration:
                                            BoxDecoration(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(4),
                                          color: Colors.white,
                                        ),
                                        child: Text(
                                          _formatPrice(newCoursesList[index].price),
                                          style: TextStyle(
                                              fontFamily:
                                                  'semibold',
                                              fontSize: 10),
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 8,
                                            vertical: 2),
                                        decoration:
                                            BoxDecoration(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(4),
                                          color: Colors.white,
                                        ),
                                        child: Text(
                                          tr(LocaleKeys.free),
                                          style:
                                              const TextStyle(
                                            fontFamily:
                                                'semibold',
                                            fontSize: 10,
                                            color: Colors.black,
                                            fontWeight:
                                                FontWeight.w500,
                                          ),
                                        ),
                                      ),
                          ),
                          if (newCoursesList[index].averageRating > 0)
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 15,
                                ),
                                Text(
                                  newCoursesList[index]
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
              ),
            ),
            const SizedBox(height: 10),
            Text(
              newCoursesList[index].title,
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