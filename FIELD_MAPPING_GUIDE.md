# LearnPress to LifterLMS Field Mapping Guide

## Course Model Field Mappings

### Basic Fields
| LearnPress (CourseModel) | LifterLMS (LLMSCourseModel) | Notes |
|--------------------------|----------------------------|-------|
| `id` | `id` | Same |
| `name` | `title` | Field renamed |
| `slug` | `slug` | Same |
| `permalink` | `permalink` | Same |
| `image` | `featuredImage` | Field renamed |
| `date_created` | `dateCreated` | Now DateTime object |
| `status` | `status` | Same |
| `on_sale` | `onSale` | camelCase |
| `content` | `content` | Same |
| `excerpt` | `excerpt` | Same |

### Pricing Fields
| LearnPress | LifterLMS | Notes |
|------------|-----------|-------|
| `price` | `price` | Same |
| `price_rendered` | Use `formatPrice(price)` | Need helper function |
| `origin_price` | `regularPrice` | Field renamed |
| `origin_price_rendered` | Use `formatPrice(regularPrice)` | Need helper function |
| `sale_price` | `salePrice` | camelCase |
| `sale_price_rendered` | Use `formatPrice(salePrice)` | Need helper function |

### Course Metadata
| LearnPress | LifterLMS | Notes |
|------------|-----------|-------|
| `duration` | `length` | In minutes |
| `rating` | `averageRating` | Field renamed |
| `count_students` | `enrollmentCount` | Field renamed |
| `instructor` | `instructors` | Now a list of LLMSInstructorModel |
| `can_retake` | Check course settings | May need custom implementation |

### Categories & Organization
| LearnPress | LifterLMS | Notes |
|------------|-----------|-------|
| `categories` (List<CategoryModel>) | `categories` (List<int>) | Now list of IDs |
| `meta_data` | Various fields | Distributed across model |
| `course_data` | Progress tracked separately | Via student endpoints |
| `sections` (List<LessonModel>) | `sections` (List<LLMSSectionModel>) | Different structure |

## View Code Migration Examples

### Before (LearnPress):
```dart
// Accessing course name
Text(course.name ?? "")

// Accessing price
Text(course.price_rendered ?? "\$${course.price}")

// Checking if on sale
if (course.on_sale == true)

// Accessing rating
Text(course.rating.toString())

// Accessing student count
Text("${course.count_students} students")

// Accessing course image
NetworkImage(course.image!)
```

### After (LifterLMS):
```dart
// Accessing course title (renamed from name)
Text(course.title)

// Accessing price (need to format)
Text(_formatPrice(course.price))

// Checking if on sale
if (course.onSale)

// Accessing rating (renamed)
Text(course.averageRating.toString())

// Accessing student count (renamed)
Text("${course.enrollmentCount} students")

// Accessing course image (renamed)
NetworkImage(course.featuredImage)
```

## Helper Functions Needed

```dart
// Price formatting helper
String _formatPrice(double price) {
  if (price == 0) return "Free";
  return "\$${price.toStringAsFixed(2)}";
}

// Get rendered price with sale
String _getDisplayPrice(LLMSCourseModel course) {
  if (course.isFree) return "Free";
  if (course.onSale && course.salePrice > 0) {
    return "\$${course.salePrice.toStringAsFixed(2)}";
  }
  return "\$${course.price.toStringAsFixed(2)}";
}

// Get original price for strikethrough
String _getOriginalPrice(LLMSCourseModel course) {
  if (course.onSale && course.regularPrice > 0) {
    return "\$${course.regularPrice.toStringAsFixed(2)}";
  }
  return "";
}
```

## Controller Updates Required

### Home Controller
- Change `List<CourseModel>` to `List<LLMSCourseModel>`
- Update parsing logic for API responses
- Adjust method signatures

### Course Detail Controller
- Update from `CourseModel` to `LLMSCourseModel`
- Change field access patterns
- Update section/lesson handling

## Common Migration Tasks

1. **Import Statement Updates**
   - Replace: `import 'package:flutter_app/app/backend/models/course_model.dart';`
   - With: `import 'package:flutter_app/app/backend/models/lifterlms/llms_course_model.dart';`

2. **Type Declarations**
   - Replace: `CourseModel`
   - With: `LLMSCourseModel`

3. **Field Access Updates**
   - Replace: `course.name`
   - With: `course.title`
   
4. **Null Safety**
   - LearnPress uses nullable fields (`String?`)
   - LifterLMS uses required fields with defaults
   - Remove null checks where fields are now required

5. **Price Display Logic**
   - Add helper functions for price formatting
   - Update sale price display logic
   - Handle "Free" courses explicitly

## Section/Lesson Structure Changes

### LearnPress Structure:
```dart
course.sections // List<LessonModel>
  - section.title
  - section.items // lessons/quizzes
```

### LifterLMS Structure:
```dart
course.sections // List<LLMSSectionModel>
  - section.title
  - section.lessons // List<LLMSLessonModel>
```

## Wishlist Handling
- LearnPress: Direct wishlist array
- LifterLMS: Needs custom endpoint or user meta
- Consider using local storage temporarily

## Testing Checklist
- [ ] Course list displays correctly
- [ ] Course titles show properly
- [ ] Prices display with correct formatting
- [ ] Sale badges appear when appropriate
- [ ] Images load correctly
- [ ] Ratings display properly
- [ ] Student counts are accurate
- [ ] Navigation to course detail works
- [ ] Categories filter correctly
- [ ] Search functionality works