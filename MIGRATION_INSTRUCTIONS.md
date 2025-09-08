# LifterLMS Migration Instructions

## 🚀 Quick Start

### 1. Configure Your API Credentials

Edit `/lib/app/config/lifterlms_config.dart`:

```dart
class LifterLMSConfig {
  static const String siteUrl = 'https://YOUR-SITE.com';
  static const String consumerKey = 'ck_YOUR_CONSUMER_KEY';
  static const String consumerSecret = 'cs_YOUR_CONSUMER_SECRET';
}
```

### 2. Get Your LifterLMS API Keys

1. Install LifterLMS REST API plugin on your WordPress site
2. Go to **LifterLMS > Settings > REST API**
3. Click **Add Key**
4. Configure:
   - Description: "Mobile App"
   - User: Select an admin user
   - Permissions: Read/Write
5. Copy the Consumer Key and Consumer Secret

### 3. Run the App

```bash
flutter clean
flutter pub get
flutter run
```

## 📁 Migration Status

### ✅ Completed Controllers
- `home_controller.dart` → `/lib/app/controller/lifterlms/home_controller.dart`
- `courses_controller.dart` → `/lib/app/controller/lifterlms/courses_controller.dart`

### 🔄 Pending Controllers
- `login_controller.dart` - Needs custom auth endpoint
- `learning_controller.dart` - Rename from "learing" + migrate
- `wishlist_controller.dart` - Rename from "wishlish" + needs custom API
- `my_courses_controller.dart` - Needs migration
- Others...

## 🔧 How to Use the New Controllers

### In Your Bindings

Replace old controller references:

```dart
// OLD
import 'package:flutter_app/app/controller/home_controller.dart';

// NEW
import 'package:flutter_app/app/controller/lifterlms/home_controller.dart';
```

### In Your Views

The controller interface remains similar:

```dart
class HomePage extends GetView<HomeController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() => 
      ListView.builder(
        itemCount: controller.topCoursesList.length,
        itemBuilder: (context, index) {
          final course = controller.topCoursesList[index];
          return CourseCard(
            title: course.title,
            price: course.price,
            onTap: () => controller.goToCourseDetail(course.id),
          );
        },
      ),
    );
  }
}
```

## 🎯 Key Differences

### 1. Models
- Old: `CourseModel`
- New: `LLMSCourseModel` with more fields

### 2. API Service
- Old: Direct API calls with JWT
- New: `LMSService` with API key auth

### 3. Enrollment
- Old: `/courses/enroll`
- New: Student-centric `/students/{id}/enrollments`

### 4. Progress Tracking
- Old: Single endpoint
- New: Granular progress per content

## 🛠️ Custom Features Needed

### 1. Wishlist Plugin

Create `/wp-content/plugins/lifterlms-wishlist/lifterlms-wishlist.php`:

```php
<?php
/**
 * Plugin Name: LifterLMS Wishlist
 * Description: Wishlist functionality for LifterLMS mobile app
 */

add_action('rest_api_init', function() {
    register_rest_route('llms-mobile/v1', '/wishlist', [
        'methods' => 'GET',
        'callback' => 'get_user_wishlist',
        'permission_callback' => 'is_user_logged_in',
    ]);
    
    register_rest_route('llms-mobile/v1', '/wishlist/add', [
        'methods' => 'POST',
        'callback' => 'add_to_wishlist',
        'permission_callback' => 'is_user_logged_in',
    ]);
    
    register_rest_route('llms-mobile/v1', '/wishlist/remove', [
        'methods' => 'POST',
        'callback' => 'remove_from_wishlist',
        'permission_callback' => 'is_user_logged_in',
    ]);
});

function get_user_wishlist($request) {
    $user_id = get_current_user_id();
    $wishlist = get_user_meta($user_id, 'llms_wishlist', true) ?: [];
    
    $courses = [];
    foreach ($wishlist as $course_id) {
        $course = new LLMS_Course($course_id);
        $courses[] = [
            'id' => $course_id,
            'title' => $course->get('title'),
            'price' => $course->get_price(),
            // Add more fields as needed
        ];
    }
    
    return new WP_REST_Response($courses, 200);
}

function add_to_wishlist($request) {
    $user_id = get_current_user_id();
    $course_id = $request->get_param('course_id');
    
    $wishlist = get_user_meta($user_id, 'llms_wishlist', true) ?: [];
    
    if (!in_array($course_id, $wishlist)) {
        $wishlist[] = $course_id;
        update_user_meta($user_id, 'llms_wishlist', $wishlist);
    }
    
    return new WP_REST_Response(['success' => true], 200);
}

function remove_from_wishlist($request) {
    $user_id = get_current_user_id();
    $course_id = $request->get_param('course_id');
    
    $wishlist = get_user_meta($user_id, 'llms_wishlist', true) ?: [];
    $wishlist = array_diff($wishlist, [$course_id]);
    
    update_user_meta($user_id, 'llms_wishlist', array_values($wishlist));
    
    return new WP_REST_Response(['success' => true], 200);
}
```

### 2. Authentication (if not using WordPress JWT)

Add custom login endpoint or use existing WordPress JWT plugin.

## 🧪 Testing Checklist

- [ ] App launches without errors
- [ ] Courses load on home screen
- [ ] Course details display correctly
- [ ] Enrollment works
- [ ] Lesson viewing works
- [ ] Progress tracking works
- [ ] Categories filter courses
- [ ] Search functionality works
- [ ] User profile loads

## 🐛 Troubleshooting

### API Connection Issues
1. Verify site URL includes `https://`
2. Check API keys are correct
3. Ensure SSL certificate is valid
4. Test API with Postman first

### Authentication Errors
1. Verify user has correct permissions
2. Check API key permissions (Read/Write)
3. Ensure user role has access to resources

### Missing Data
1. Check if LifterLMS has courses published
2. Verify course visibility settings
3. Check user enrollment status

## 📞 Support

- LifterLMS Docs: https://lifterlms.com/docs/
- REST API Docs: https://developer.lifterlms.com/rest-api/
- GitHub Issues: https://github.com/gocodebox/lifterlms-rest/issues

## ✅ Next Steps

1. Complete remaining controller migrations
2. Update all view files to use new models
3. Test with real LifterLMS instance
4. Deploy to production

---

**Note**: Keep this document updated as you progress through the migration!