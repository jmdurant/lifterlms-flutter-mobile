import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/mobx-store/wishlist_store.dart';
import 'package:flutter_app/app/backend/models/course_model.dart';
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';
import 'package:flutter_app/app/controller/lifterlms/wishlist_controller.dart';
import 'package:flutter_app/app/helper/function_helper.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/l10n/locale_keys.g.dart';
import 'package:get/get.dart';
import 'package:watch_it/watch_it.dart';

import '../../backend/parse/course_detail_parse.dart';
import '../course_detail.dart';

typedef OnToggleWishlistCallback = void Function();

// Separate widget for the heart icon
class WishlistHeart extends StatefulWidget {
  final int courseId;
  final VoidCallback onToggle;
  
  const WishlistHeart({
    Key? key,
    required this.courseId,
    required this.onToggle,
  }) : super(key: key);
  
  @override
  _WishlistHeartState createState() => _WishlistHeartState();
}

class _WishlistHeartState extends State<WishlistHeart> {
  late bool _isInWishlist;
  late WishlistController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = Get.find<WishlistController>();
    _isInWishlist = _controller.isInWishlist(widget.courseId);
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // Toggle state immediately for visual feedback
        setState(() {
          _isInWishlist = !_isInWishlist;
        });
        
        // Call the controller
        await _controller.toggleWishlist(widget.courseId);
        
        // Check actual state and update if needed
        if (mounted) {
          final actualState = _controller.isInWishlist(widget.courseId);
          if (actualState != _isInWishlist) {
            setState(() {
              _isInWishlist = actualState;
            });
          }
        }
        
        widget.onToggle();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          color: _isInWishlist 
            ? Colors.red.withOpacity(0.8)
            : Colors.black.withOpacity(0.2),
        ),
        child: Icon(
          _isInWishlist 
            ? Icons.favorite 
            : Icons.favorite_border,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class ItemCourse extends WatchingWidget {
  final dynamic item; // Can be CourseModel or LLMSCourseModel
  bool hideCategory = false;
  final CourseDetailParser courseDetailParser;

  final OnToggleWishlistCallback onToggleWishlist;

  ItemCourse(
      {super.key,
      required this.item,
      required this.onToggleWishlist,
      required this.courseDetailParser,
      hideCategory
      });

  void onNavigate() {
    final courseId = item is CourseModel ? item.id : (item as LLMSCourseModel).id;
    Get.toNamed(AppRouter.getCourseDetailRoute(),
        arguments: [courseId], preventDuplicates: false);
  }

  final WishlistStore wishlistStore = Get.find<WishlistStore>();
  
  // Get course ID for wishlist checking
  int _getCourseId() {
    if (item is CourseModel) {
      return item.id ?? 0;
    } else if (item is LLMSCourseModel) {
      return item.id;
    }
    return 0;
  }

  // Helper methods to handle both model types
  ImageProvider _getItemImage() {
    String imageUrl = '';
    if (item is CourseModel) {
      imageUrl = item.image ?? '';
    } else if (item is LLMSCourseModel) {
      imageUrl = item.featuredImage;
    }
    
    if (imageUrl.isNotEmpty && !imageUrl.contains('placeholder')) {
      return NetworkImage(imageUrl);
    }
    return Image.asset("assets/images/placeholder-500x300.png").image;
  }
  
  bool _isOnSale() {
    if (item is CourseModel) {
      return item.on_sale == true;
    } else if (item is LLMSCourseModel) {
      return item.onSale;
    }
    return false;
  }
  
  String _getItemTitle() {
    if (item is CourseModel) {
      return item.name ?? '';
    } else if (item is LLMSCourseModel) {
      return item.title;
    }
    return '';
  }
  
  double _getItemPrice() {
    if (item is CourseModel) {
      return item.price ?? 0;
    } else if (item is LLMSCourseModel) {
      return item.price;
    }
    return 0;
  }
  
  double _getSalePrice() {
    if (item is CourseModel) {
      return item.sale_price ?? 0;
    } else if (item is LLMSCourseModel) {
      return item.salePrice;
    }
    return 0;
  }
  
  double _getRegularPrice() {
    if (item is CourseModel) {
      return item.origin_price ?? 0;
    } else if (item is LLMSCourseModel) {
      return item.regularPrice;
    }
    return 0;
  }
  
  double _getRating() {
    if (item is CourseModel) {
      return item.rating ?? 0;
    } else if (item is LLMSCourseModel) {
      return item.averageRating;
    }
    return 0;
  }
  
  String _formatPrice(double price) {
    if (price == 0) return tr(LocaleKeys.free);
    return "\$${price.toStringAsFixed(2)}";
  }
  
  String _getCategoriesText() {
    if (item is CourseModel && item.categories != null) {
      return item.categories!.map((e) => e.name).join(',');
    } else if (item is LLMSCourseModel) {
      // For LifterLMS, categories are just IDs, would need to fetch names
      return '';
    }
    return '';
  }
  
  bool _hasCategories() {
    if (item is CourseModel) {
      return item.categories != null && item.categories!.isNotEmpty;
    }
    return false;
  }
  
  String _getDuration() {
    if (item is CourseModel) {
      return item.duration ?? '';
    } else if (item is LLMSCourseModel) {
      // LifterLMS stores duration in minutes
      return '${item.length} minutes';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => onNavigate(),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Stack(children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      // width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: _getItemImage(),
                        ), // Widget con của
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 15,
                    child: WishlistHeart(courseId: _getCourseId(), onToggle: onToggleWishlist),
                  ),
                  _isOnSale()
                      ? Positioned(
                          top: 10,
                          left: 15,
                          child: Container(
                            width: 49,
                            height: 21,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBC815),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                tr(LocaleKeys.sale),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFamily: 'medium'),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_isOnSale())
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.white,
                              ),
                              child: Wrap(
                                direction: Axis.horizontal,
                                children: [
                                  Text(
                                    _formatPrice(_getSalePrice()),
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 10,
                                  ),
                                  Text(
                                    _formatPrice(_getRegularPrice()),
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      color: Colors.black45,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_getItemPrice() > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.white,
                              ),
                              child: Text(
                                _formatPrice(_getItemPrice()),
                                style: TextStyle(
                                  fontFamily: 'medium',
                                  fontSize: 14
                                ),
                                // style: styles.price,
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.white,
                              ),
                              child: Text(
                                tr(LocaleKeys.free),
                                style: const TextStyle(
                                  fontFamily: 'medium',
                                  fontSize: 14,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          if (_getRating() > 0)
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(
                                  width: 4,
                                ),
                                Text(
                                  _getRating().toStringAsFixed(1),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontFamily: 'medium',
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ]),
                if (_hasCategories() && !hideCategory)
                  Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      width: double.infinity,
                      child: Text(
                        _getCategoriesText(),
                        style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'poppins',
                            color: Color(0xFF939393)),
                      )),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getItemTitle(),
                          maxLines: 2,
                          style: const TextStyle(
                            fontFamily: "medium",
                            fontSize: 16,
                          ),
                        )
                      ]),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/icon/icon-clock.png',
                        width: 20,
                        height: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        tr(LocaleKeys.durations),
                        style: const TextStyle(
                          fontFamily: 'medium',
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        Helper.handleTranslationsDuration(_getDuration()),
                        style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'poppins',
                            color: Color(0xFF939393)),
                      ),
                    ],
                  ),
                ),
              ],
            )));
  }
}
