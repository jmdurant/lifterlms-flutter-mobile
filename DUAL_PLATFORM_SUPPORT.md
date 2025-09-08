# Dual Platform Support - LearnPress & LifterLMS

## Overview

This app now supports **both LearnPress and LifterLMS** platforms! You can switch between them dynamically without rebuilding the app.

## Quick Start

### 1. Configure Your Platforms

Edit `/lib/app/config/lms_config.dart`:

```dart
class LMSConfig {
  // Choose default platform: 'learnpress' or 'lifterlms'
  static String platform = 'learnpress';
  
  // LearnPress Configuration
  static const String learnPressUrl = 'https://your-learnpress-site.com';
  
  // LifterLMS Configuration  
  static const String lifterLMSUrl = 'https://your-lifterlms-site.com';
  static const String lifterLMSConsumerKey = 'ck_xxxxx';
  static const String lifterLMSConsumerSecret = 'cs_xxxxx';
}
```

### 2. Initialize in main.dart

```dart
import 'package:flutter_app/app/util/lms_platform_init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize with default platform from config
  await LMSPlatformInit.initialize();
  
  // OR initialize with specific platform
  await LMSPlatformInit.setupLearnPress(
    baseUrl: 'https://learn.example.com',
  );
  
  // OR
  await LMSPlatformInit.setupLifterLMS(
    baseUrl: 'https://lifter.example.com',
    consumerKey: 'ck_xxxxx',
    consumerSecret: 'cs_xxxxx',
  );
  
  runApp(MyApp());
}
```

### 3. Switch Platforms at Runtime

#### Option A: Use the Platform Switcher Widget

Add to your settings screen:

```dart
import 'package:flutter_app/app/view/components/platform_switcher.dart';

// In your widget
PlatformSwitcher()

// Or show as dialog
PlatformSwitcherDialog.show();
```

#### Option B: Switch Programmatically

```dart
import 'package:flutter_app/app/backend/services/lms_platform_service.dart';

// Switch to LifterLMS
final service = Get.find<LMSPlatformService>();
await service.switchPlatform('lifterlms');

// Switch to LearnPress
await service.switchPlatform('learnpress');
```

## Architecture

### 1. Platform Configuration
- **Location**: `/lib/app/config/lms_config.dart`
- **Purpose**: Stores platform settings and credentials
- **Features**: Platform detection, configuration management

### 2. API Layer

#### Interface
- **Location**: `/lib/app/backend/api/lms_api_interface.dart`
- **Purpose**: Common interface for all LMS platforms

#### Implementations
- **LearnPress**: `/lib/app/backend/api/learnpress_api_impl.dart`
- **LifterLMS**: `/lib/app/backend/api/lifterlms_api.dart`

### 3. Service Layer
- **Location**: `/lib/app/backend/services/lms_platform_service.dart`
- **Purpose**: Manages API instances and platform switching
- **Features**: Authentication, session management, platform switching

### 4. Controllers

#### LearnPress Controllers
- **Location**: `/lib/app/controller/` (original controllers)
- **Models**: `/lib/app/backend/models/` (CourseModel, etc.)

#### LifterLMS Controllers
- **Location**: `/lib/app/controller/lifterlms/`
- **Models**: `/lib/app/backend/models/lifterlms/` (LLMSCourseModel, etc.)

### 5. Dynamic Binding
- **Location**: `/lib/app/backend/binding/lms_dynamic_binding.dart`
- **Purpose**: Loads appropriate controllers based on active platform
- **Features**: Controller resolution, dynamic loading

## How It Works

### Platform Detection Flow

```
App Start
    ↓
Check Saved Platform Preference
    ↓
Load Configuration (LMSConfig)
    ↓
Initialize API (LearnPress or LifterLMS)
    ↓
Load Controllers (Platform-specific)
    ↓
App Ready
```

### Platform Switching Flow

```
User Triggers Switch
    ↓
Clear Current Session
    ↓
Update Configuration
    ↓
Reinitialize API
    ↓
Reload Controllers
    ↓
Navigate to Home
```

## API Differences

### Authentication

**LearnPress**:
- Uses JWT tokens
- Login endpoint: `/wp-json/learnpress/v1/token`
- Token-based authentication

**LifterLMS**:
- Uses API keys (consumer key/secret)
- Basic Auth with API credentials
- No login endpoint needed for API access

### Data Models

**Course Fields**:
| LearnPress | LifterLMS |
|------------|-----------|
| `name` | `title` |
| `image` | `featuredImage` |
| `on_sale` | `onSale` |
| `rating` | `averageRating` |
| `count_students` | `enrollmentCount` |

### Enrollment

**LearnPress**:
```dart
POST /courses/enroll
Body: { id: courseId }
```

**LifterLMS**:
```dart
POST /students/{studentId}/enrollments/{courseId}
```

## Views Compatibility

The views automatically adapt to the active platform:

1. **Smart Components**: `ItemCourse` widget handles both models
2. **Controller Resolution**: Views get the right controller automatically
3. **Model Adapters**: Helper methods abstract field differences

## Testing

### Test Platform Switching

```dart
// In debug mode, add this to any screen
ElevatedButton(
  onPressed: () => PlatformSwitcherDialog.show(),
  child: Text('Switch Platform'),
)
```

### Check Current Platform

```dart
import 'package:flutter_app/app/config/lms_config.dart';

print('Current platform: ${LMSConfig.platformName}');
print('Is LearnPress: ${LMSConfig.isLearnPress}');
print('Is LifterLMS: ${LMSConfig.isLifterLMS}');
```

### Platform-Specific Code

```dart
if (LMSConfig.isLearnPress) {
  // LearnPress specific code
} else {
  // LifterLMS specific code
}
```

## Troubleshooting

### Platform Switch Not Working

1. Check if service is initialized:
```dart
if (LMSPlatformInit.isInitialized) {
  // Service is ready
}
```

2. Clear app data and restart
3. Check console for error messages

### API Connection Issues

**LearnPress**:
- Verify JWT Authentication plugin is installed
- Check if API endpoints are accessible
- Ensure user has proper permissions

**LifterLMS**:
- Verify REST API plugin is installed
- Check API keys are valid
- Ensure keys have read/write permissions

### Controller Not Found

If you get "Controller not found" errors:

1. Make sure controllers are loaded:
```dart
LMSDynamicBinding().dependencies();
```

2. Use the resolver for safety:
```dart
final controller = LMSControllerResolver.getHomeController();
```

## Advanced Usage

### Custom Platform Implementation

To add a new LMS platform:

1. Create API implementation:
```dart
class MoodleAPI implements LMSAPIInterface {
  // Implement all methods
}
```

2. Update LMSConfig:
```dart
static String platform = 'moodle';
```

3. Update service initialization:
```dart
if (LMSConfig.platform == 'moodle') {
  api = MoodleAPI();
}
```

4. Create controllers for the platform

### Conditional Features

Some features may only be available on certain platforms:

```dart
// In your view
if (LMSConfig.isLifterLMS) {
  // Show LifterLMS-only features like Memberships
  MembershipSection()
}

if (LMSConfig.isLearnPress) {
  // Show LearnPress-only features
  LearnPressFeature()
}
```

## Benefits

1. **Single Codebase**: Maintain one app for multiple LMS platforms
2. **Easy Migration**: Test both platforms during migration
3. **Client Flexibility**: Deploy to different clients with different LMS
4. **A/B Testing**: Compare platform performance
5. **Gradual Migration**: Switch users gradually
6. **Fallback Option**: Quick rollback if issues arise

## Limitations

### LearnPress Limitations
- No native membership support
- Limited progress tracking API
- Wishlist requires custom endpoint

### LifterLMS Limitations
- Quizzes API coming soon (PR #346)
- Assignments API in development
- Social login needs custom implementation

## Performance Considerations

- Controllers are loaded lazily
- Only active platform's controllers are in memory
- API instances are singleton
- Platform switch clears all caches

## Security

- Credentials are stored in SharedPreferences
- API keys are never exposed in UI
- Token refresh handled automatically
- Session cleared on platform switch

## Next Steps

1. **Production Setup**:
   - Set production URLs in config
   - Add proper API credentials
   - Test thoroughly on both platforms

2. **Customization**:
   - Customize UI per platform if needed
   - Add platform-specific features
   - Implement missing endpoints

3. **Monitoring**:
   - Add analytics per platform
   - Track platform usage
   - Monitor API performance

## Support

- **LearnPress**: [Documentation](https://thimpress.com/learnpress/)
- **LifterLMS**: [REST API Docs](https://developer.lifterlms.com/rest-api/)
- **Issues**: Create issue in this repository