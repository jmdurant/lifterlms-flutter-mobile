import 'package:flutter/material.dart';
import 'package:flutter_app/app/controller/lifterlms/wishlist_controller.dart';
import 'package:flutter_app/app/controller/tabs_controller.dart';
import 'package:flutter_app/app/backend/parse/course_detail_parse.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/view/components/item-course.dart';
import 'package:get/get.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WishlistController wishlistController = Get.find<WishlistController>();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load initial data
    if (wishlistController.lmsService.isLoggedIn) {
      wishlistController.loadWishlist();
      _loadFavoriteLessons();
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadFavoriteLessons() async {
    // TODO: Load favorite lessons/sections
    // This will call the API to get favorited lessons and sections
  }
  
  void onLogin() {
    Get.toNamed(AppRouter.getLoginRoute());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite,
                    color: Colors.red,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Favorites & Wishlist',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Tab Bar
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.school, size: 18),
                        SizedBox(width: 8),
                        Text('Wishlist Courses'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark, size: 18),
                        SizedBox(width: 8),
                        Text('Saved Lessons'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16),
            
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Wishlist Courses Tab
                  _buildWishlistTab(),
                  
                  // Favorite Lessons Tab
                  _buildFavoriteLessonsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWishlistTab() {
    return GetBuilder<WishlistController>(
      builder: (controller) {
        if (!controller.lmsService.isLoggedIn) {
          return _buildLoginPrompt('Sign in to save courses to your wishlist');
        }
        
        if (controller.isLoading.value && controller.wishlistCourses.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (controller.wishlistCourses.isEmpty) {
          return _buildEmptyState(
            icon: Icons.school_outlined,
            title: 'No Courses in Wishlist',
            subtitle: 'Browse courses and add them to your wishlist to save them for later',
            actionText: 'Browse Courses',
            onAction: () => Get.toNamed(AppRouter.getCoursesByCategory()),
          );
        }
        
        return RefreshIndicator(
          onRefresh: () => controller.loadWishlist(isRefresh: true),
          child: ListView.builder(
            controller: controller.scrollController,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: controller.wishlistCourses.length + 
                     (controller.isLoadingMore.value ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == controller.wishlistCourses.length) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              final course = controller.wishlistCourses[index];
              return Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ItemCourse(
                  item: course,
                  onToggleWishlist: () {
                    // Refresh wishlist after toggle
                    controller.loadWishlist(isRefresh: true);
                  },
                  courseDetailParser: Get.find(),
                ),
              );
            },
          ),
        );
      },
    );
  }
  
  Widget _buildFavoriteLessonsTab() {
    // TODO: Implement favorite lessons list
    // This will show lessons and sections that users have bookmarked
    return _buildEmptyState(
      icon: Icons.bookmark_outline,
      title: 'No Saved Lessons',
      subtitle: 'Bookmark lessons while learning to quickly access them later',
      actionText: 'Go to My Courses',
      onAction: () {
        // Navigate to My Courses tab
        final tabsController = Get.find<TabControllerX>();
        tabsController.updateTabId(2); // My Courses tab
      },
    );
  }
  
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(actionText),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoginPrompt(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 24),
            Text(
              'Sign In Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: onLogin,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}