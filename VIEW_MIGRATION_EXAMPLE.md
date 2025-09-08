# View Migration Example - Home Screen

## Key Issues to Fix in Views

### 1. Controller Property Changes

The new LifterLMS controllers have different property names and don't have the `parser` object for user info.

**Old LearnPress Controller Properties:**
- `value.parser.getToken()` - for auth check
- `value.parser.getUserInfo()` - for user data
- `value.overview` - for overview data
- `value.cateHomeList` - for categories
- `value.topCoursesList` - for top courses
- `value.newCourseList` - for new courses
- `value.instructorList` - for instructors

**New LifterLMS Controller Properties:**
- `value.lmsService.isLoggedIn` - for auth check
- `value.lmsService.currentUser` - for user data (needs to be added)
- No overview property - needs custom implementation
- `value.categoriesList` - for categories
- `value.topCoursesList` - for top courses (same)
- `value.newCoursesList` - for new courses (different name)
- `value.instructorsList` - for instructors (different name)

### 2. Required Changes in home.dart

```dart
// OLD CODE (lines 116-117)
value.parser.getToken() == ''

// NEW CODE
!value.lmsService.isLoggedIn
```

```dart
// OLD CODE (lines 172)
value.parser.getToken() != ""

// NEW CODE
value.lmsService.isLoggedIn
```

```dart
// OLD CODE (lines 189-205) - User avatar
value.parser.getUserInfo().avatar_url != ""
    ? Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            image: DecorationImage(
              fit: BoxFit.cover,
              image: NetworkImage(value.parser.getUserInfo().avatar_url),
            )))

// NEW CODE - Need to add currentUser to controller or use lmsService
value.lmsService.currentUser?.avatarUrl != null
    ? Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            image: DecorationImage(
              fit: BoxFit.cover,
              image: NetworkImage(value.lmsService.currentUser!.avatarUrl),
            )))
```

```dart
// OLD CODE (lines 246-249) - Overview widget
if (value.parser.getToken() != "" &&
    value.overview != null &&
    value.overview["id"] != null)
  Overview(overview: value.overview),

// NEW CODE - Comment out or implement differently
// Overview feature needs custom implementation for LifterLMS
// if (value.lmsService.isLoggedIn && value.userProgress != null)
//   Overview(overview: value.userProgress),
```

```dart
// OLD CODE (lines 250-257) - Component lists
Categories(categoriesList: value.cateHomeList),
TopCourse(topCoursesList: value.topCoursesList),
NewCourse(newCoursesList: value.newCourseList),
Instructors(instructorList: value.instructorList),

// NEW CODE - Updated property names
Categories(categoriesList: value.categoriesList),
TopCourse(topCoursesList: value.topCoursesList),
NewCourse(newCoursesList: value.newCoursesList),  // Note: newCoursesList not newCourseList
Instructors(instructorList: value.instructorsList), // Note: instructorsList not instructorList
```

### 3. Other Component Updates Needed

#### new-course.dart
```dart
// Update import
import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';

// Update type
final List<LLMSCourseModel> newCoursesList;

// Update field access
course.title // instead of course.name
course.featuredImage // instead of course.image
course.onSale // instead of course.on_sale
course.averageRating // instead of course.rating
```

#### categories.dart
```dart
// Categories might need different structure
// Check if categories are objects or just IDs
```

#### instructors.dart
```dart
// Update import
import 'package:flutter_app/app/backend/models/lifterlms/llms_instructor_model.dart';

// Update type
final List<LLMSInstructorModel> instructorList;

// Update field access based on new model
```

### 4. Wishlist Handling

The old code uses a MobX store for wishlist:
```dart
wishlistStore.data.any((element) => element.id == course.id)
```

The new controller has wishlist methods:
```dart
value.isInWishlist(course.id)
value.toggleWishlist(course.id)
```

### 5. Complete home.dart Migration Steps

1. **Update imports**
   - Change to LifterLMS controller
   - Update model imports in components

2. **Fix authentication checks**
   - Replace `parser.getToken()` with `lmsService.isLoggedIn`
   - Replace `parser.getUserInfo()` with proper user service

3. **Update property names**
   - `newCourseList` → `newCoursesList`
   - `instructorList` → `instructorsList`
   - `cateHomeList` → `categoriesList`

4. **Handle missing features**
   - Overview widget - needs custom implementation
   - User checkout - needs review
   - Notification status - already in new controller

5. **Update child components**
   - Each component needs model and field updates
   - Price formatting needs helper functions
   - Wishlist needs new implementation

### 6. Testing Checklist

After migration, test:
- [ ] Home screen loads without errors
- [ ] User authentication state displays correctly
- [ ] User avatar and info display when logged in
- [ ] Login/Register buttons show when logged out
- [ ] Categories load and display
- [ ] Top courses load with correct data
- [ ] New courses load with correct data
- [ ] Instructors load and display
- [ ] Wishlist toggle works
- [ ] Navigation to course detail works
- [ ] Notification icon displays correctly

### 7. Common Errors to Watch For

1. **Null safety issues**
   - Old models use nullable fields (`String?`)
   - New models use required fields with defaults
   - Remove unnecessary null checks

2. **Type mismatches**
   - `CourseModel` vs `LLMSCourseModel`
   - `List<CategoryModel>` vs `List<int>` for categories

3. **Missing methods**
   - `parser` methods don't exist in new controller
   - Need to add user management to controller or use service directly

4. **API response format**
   - LifterLMS uses WordPress REST API format
   - Some fields are nested (e.g., `title.rendered`)

### 8. Helper Functions to Add

Add these to your view files or a shared utility:

```dart
// Format price display
String formatCoursePrice(LLMSCourseModel course) {
  if (course.isFree) return "Free";
  if (course.onSale && course.salePrice > 0) {
    return "\$${course.salePrice.toStringAsFixed(2)}";
  }
  return "\$${course.price.toStringAsFixed(2)}";
}

// Get original price for strikethrough
String formatOriginalPrice(LLMSCourseModel course) {
  if (course.onSale && course.regularPrice > 0) {
    return "\$${course.regularPrice.toStringAsFixed(2)}";
  }
  return "";
}

// Format rating display
String formatRating(double rating) {
  return rating > 0 ? rating.toStringAsFixed(1) : "No ratings";
}
```