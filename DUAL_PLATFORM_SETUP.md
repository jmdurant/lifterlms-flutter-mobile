# Dual Platform Support: LearnPress & LifterLMS

## ✅ Current Setup Status

The Flutter app now supports **BOTH** LearnPress and LifterLMS platforms with dynamic switching capability.

### Key Components:

1. **Platform Configuration** (`/lib/app/config/lms_config.dart`)
   - Currently set to: **LifterLMS**
   - Switch between platforms at runtime
   - Stores API credentials for both platforms

2. **Dynamic Binding System** (`/lib/app/backend/binding/lms_dynamic_binding.dart`)
   - Loads appropriate controllers based on selected platform
   - `LMSControllerResolver` class provides platform-agnostic controller access
   - Fixed typos: `LearningController` and `WishlistController`

3. **Platform Switcher UI** (`/lib/app/view/components/platform_switcher.dart`)
   - Visual component to switch between platforms
   - Shows current platform status
   - Handles controller reloading on switch

4. **Main App Integration** (`/lib/main.dart`)
   - Uses dynamic binding instead of hardcoded controllers
   - Initializes based on config setting

## 🔧 How It Works

### Controller Resolution
Instead of directly importing controllers, views use:
```dart
// OLD WAY (platform-specific)
import 'package:flutter_app/app/controller/lifterlms/home_controller.dart';
final HomeController controller = Get.find<HomeController>();

// NEW WAY (platform-agnostic)
import 'package:flutter_app/app/backend/binding/lms_dynamic_binding.dart';
final controller = LMSControllerResolver.getHomeController();
```

### Platform Switching
```dart
// Switch to LearnPress
LMSConfig.switchPlatform('learnpress');
LMSDynamicBinding.reloadControllers();

// Switch to LifterLMS
LMSConfig.switchPlatform('lifterlms');
LMSDynamicBinding.reloadControllers();
```

## 📝 Configuration

### LearnPress Setup
Edit `/lib/app/config/lms_config.dart`:
```dart
static const String learnPressUrl = 'https://your-learnpress-site.com';
static const String learnPressApiPath = '/wp-json/learnpress/v1';
```

### LifterLMS Setup
Edit `/lib/app/config/lms_config.dart`:
```dart
static const String lifterLMSUrl = 'https://your-lifterlms-site.com';
static const String lifterLMSConsumerKey = 'ck_your_key';
static const String lifterLMSConsumerSecret = 'cs_your_secret';
```

## 🚀 Usage

### In Settings/Profile
Add the platform switcher:
```dart
// In your settings view
PlatformSwitcher()

// Or show as dialog
PlatformSwitcherDialog.show()
```

### Run Update Scripts

1. **Update Views** (if needed):
```bash
chmod +x update_views_for_dynamic_binding.sh
./update_views_for_dynamic_binding.sh
```

2. **Update Parsers** (for API compatibility):
```bash
chmod +x update_parsers_for_lifterlms.sh
./update_parsers_for_lifterlms.sh
```

## 🎯 What's Working

- ✅ Dynamic controller loading based on platform
- ✅ Platform switching at runtime
- ✅ LifterLMS controllers fully implemented
- ✅ LearnPress controllers preserved
- ✅ UI component for platform switching
- ✅ Resolver pattern for platform-agnostic code

## ⚠️ Important Notes

1. **Controller Class Names**: LearnPress has typos in filenames but correct class names:
   - File: `learing_controller.dart` → Class: `LearningController`
   - File: `wishlish_controller.dart` → Class: `WishlistController`

2. **View Updates**: Views need to use `LMSControllerResolver` instead of direct `Get.find<Controller>()`

3. **API Differences**: Each platform has different API structures:
   - LearnPress: JWT authentication
   - LifterLMS: Basic Auth with consumer keys

## 🧪 Testing

1. Set platform to LearnPress:
   - Update config to `platform = 'learnpress'`
   - Run app and verify LearnPress API calls

2. Set platform to LifterLMS:
   - Update config to `platform = 'lifterlms'`
   - Run app and verify LifterLMS API calls

3. Test runtime switching:
   - Use PlatformSwitcher component
   - Verify controllers reload properly
   - Check API calls switch to correct platform

## 📁 File Structure

```
lib/
├── app/
│   ├── backend/
│   │   ├── binding/
│   │   │   └── lms_dynamic_binding.dart    # Dynamic controller loading
│   │   ├── api/
│   │   │   ├── lifterlms_api.dart         # LifterLMS API service
│   │   │   └── api.dart                    # LearnPress API service
│   │   └── services/
│   │       └── lms_service.dart           # Unified LMS service
│   ├── config/
│   │   └── lms_config.dart                # Platform configuration
│   ├── controller/
│   │   ├── lifterlms/                     # LifterLMS controllers
│   │   │   ├── home_controller.dart
│   │   │   ├── courses_controller.dart
│   │   │   └── ...
│   │   ├── home_controller.dart           # LearnPress controllers
│   │   ├── courses_controller.dart
│   │   └── ...
│   └── view/
│       ├── components/
│       │   └── platform_switcher.dart     # Platform switch UI
│       └── home.dart                       # Updated to use resolver
└── main.dart                               # Dynamic binding initialization
```

## 🔄 Next Steps

1. Run the view update script to convert all views
2. Test both platforms thoroughly
3. Add platform indicator in app UI
4. Configure production API credentials
5. Deploy and test in production environment