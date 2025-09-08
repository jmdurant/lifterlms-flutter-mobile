# Authentication Setup for Dual Platform Support

## Overview

Authentication works differently for LearnPress and LifterLMS. This guide explains how to set up authentication for both platforms.

## Quick Comparison

| Feature | LearnPress | LifterLMS |
|---------|------------|-----------|
| **API Auth** | None required | API Keys (Consumer Key/Secret) |
| **User Auth** | JWT Token | JWT Token or App Password |
| **Login Endpoint** | Built-in | Requires plugin |
| **Session** | Token-based | Token or Cookie-based |

## LearnPress Authentication ✅

**Works out of the box!**

LearnPress has built-in JWT authentication:

1. User logs in with username/password
2. Receives JWT token
3. Token sent with each request
4. No additional setup needed

```dart
// Login
POST /wp-json/learnpress/v1/token
Body: { username, password }

// Response
{
  "token": "eyJ0eXAiOiJKV1...",
  "user": { id, email, display_name }
}
```

## LifterLMS Authentication ⚠️

**Requires additional setup!**

LifterLMS REST API uses API keys for server authentication, but doesn't provide user login endpoints by default.

### Option 1: JWT Authentication Plugin (Recommended) ✅

1. **Install Plugin**: [JWT Authentication for WP REST API](https://wordpress.org/plugins/jwt-authentication-for-wp-rest-api/)

2. **Configure wp-config.php**:
```php
define('JWT_AUTH_SECRET_KEY', 'your-top-secret-key');
define('JWT_AUTH_CORS_ENABLE', true);
```

3. **Login works like LearnPress**:
```dart
POST /wp-json/jwt-auth/v1/token
Body: { username, password }
```

### Option 2: Application Passwords (WordPress 5.6+) ✅

1. **Generate App Password**:
   - Go to WordPress Admin → Users → Your Profile
   - Scroll to "Application Passwords"
   - Enter a name (e.g., "Mobile App")
   - Click "Add New Application Password"
   - Copy the generated password

2. **Use in App**:
```dart
// Login with app password instead of regular password
Username: your-username
Password: xxxx-xxxx-xxxx-xxxx (app password)
```

### Option 3: Custom Login Endpoint 🔧

Create a custom plugin for LifterLMS login:

```php
// wp-content/plugins/llms-mobile-auth/llms-mobile-auth.php
<?php
/**
 * Plugin Name: LifterLMS Mobile Authentication
 */

add_action('rest_api_init', function() {
    // Login endpoint
    register_rest_route('llms-mobile/v1', '/login', [
        'methods' => 'POST',
        'callback' => 'llms_mobile_login',
        'permission_callback' => '__return_true',
    ]);
    
    // Validate token endpoint
    register_rest_route('llms-mobile/v1', '/validate', [
        'methods' => 'GET',
        'callback' => 'llms_mobile_validate',
        'permission_callback' => 'is_user_logged_in',
    ]);
});

function llms_mobile_login($request) {
    $username = $request->get_param('username');
    $password = $request->get_param('password');
    
    $user = wp_authenticate($username, $password);
    
    if (is_wp_error($user)) {
        return new WP_Error('login_failed', 'Invalid credentials', ['status' => 401]);
    }
    
    // Generate a token (you can use JWT or custom token)
    $token = wp_generate_password(32, false);
    
    // Save token as user meta
    update_user_meta($user->ID, 'mobile_auth_token', $token);
    
    return [
        'success' => true,
        'token' => $token,
        'user' => [
            'id' => $user->ID,
            'email' => $user->user_email,
            'display_name' => $user->display_name,
            'roles' => $user->roles,
        ]
    ];
}

function llms_mobile_validate($request) {
    $user = wp_get_current_user();
    
    return [
        'valid' => true,
        'user' => [
            'id' => $user->ID,
            'email' => $user->user_email,
            'display_name' => $user->display_name,
        ]
    ];
}

// Add token validation
add_filter('determine_current_user', function($user) {
    $token = $_SERVER['HTTP_X_AUTH_TOKEN'] ?? '';
    
    if ($token) {
        $users = get_users([
            'meta_key' => 'mobile_auth_token',
            'meta_value' => $token,
            'number' => 1,
        ]);
        
        if (!empty($users)) {
            return $users[0]->ID;
        }
    }
    
    return $user;
}, 20);
```

## How the App Handles Authentication

The app automatically detects the platform and uses the appropriate authentication:

```dart
// In UnifiedAuthService
if (LMSConfig.isLearnPress) {
  // Use LearnPress JWT endpoint
  response = await loginLearnPress(username, password);
} else {
  // Try LifterLMS methods in order:
  // 1. JWT Plugin
  // 2. App Password
  // 3. Custom endpoint
  response = await loginLifterLMS(username, password);
}
```

## Testing Authentication

### Test LearnPress Login
```bash
curl -X POST https://your-learnpress-site.com/wp-json/learnpress/v1/token \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test123"}'
```

### Test LifterLMS with JWT Plugin
```bash
curl -X POST https://your-lifterlms-site.com/wp-json/jwt-auth/v1/token \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test123"}'
```

### Test LifterLMS with App Password
```bash
curl -X GET https://your-lifterlms-site.com/wp-json/wp/v2/users/me \
  -H "Authorization: Basic $(echo -n 'username:app-password' | base64)"
```

## Troubleshooting

### LifterLMS Login Not Working

1. **Check JWT Plugin**:
   - Is plugin activated?
   - Is JWT_AUTH_SECRET_KEY defined in wp-config.php?
   - Check error logs for JWT errors

2. **Check Custom Endpoint (if using)**:
   - Plugin activated?
   - Endpoint accessible?
   - Test with Postman/curl

### "Authentication Required" Errors

For LifterLMS API requests, you need both:
- **API Authentication**: Consumer Key/Secret (for API access)
- **User Authentication**: JWT/App Password (for user identity)

The app handles this automatically once configured.

## Security Considerations

1. **Use HTTPS**: Always use SSL/TLS for production
2. **Strong Secrets**: Use strong JWT secrets and API keys
3. **Token Expiry**: Configure appropriate token expiration
4. **App Passwords**: Treat app passwords like regular passwords
5. **Revoke Access**: Implement token/session revocation

## Platform-Specific Features

### LearnPress
- ✅ Login/Logout
- ✅ Registration
- ✅ Password Reset
- ✅ Profile Update
- ✅ Token Refresh

### LifterLMS (with JWT Plugin)
- ✅ Login/Logout
- ✅ Registration (custom endpoint needed)
- ✅ Password Reset (via WordPress)
- ✅ Profile Update
- ⚠️ Token Refresh (depends on plugin)

## Code Examples

### Using UnifiedAuthService

```dart
import 'package:flutter_app/app/backend/services/unified_auth_service.dart';

class LoginController extends GetxController {
  final authService = UnifiedAuthService.to;
  
  Future<void> login() async {
    final response = await authService.login(
      username: usernameController.text,
      password: passwordController.text,
    );
    
    if (response.statusCode == 200) {
      // Success - works for both platforms!
      Get.offAllNamed('/home');
    } else {
      // Handle error
      if (authService.needsAuthSetup) {
        // Show setup instructions for LifterLMS
        Get.dialog(
          AlertDialog(
            title: Text('Setup Required'),
            content: Text(authService.authSetupInstructions),
          ),
        );
      }
    }
  }
}
```

### Checking Authentication State

```dart
// In any controller or view
if (UnifiedAuthService.to.isLoggedIn) {
  // User is logged in
  print('User ID: ${UnifiedAuthService.to.userId}');
  print('Email: ${UnifiedAuthService.to.userEmail}');
}
```

### Making Authenticated Requests

```dart
// Headers are automatically added based on platform
final headers = UnifiedAuthService.to.getAuthHeaders();

// Use with any API call
final response = await http.get(
  Uri.parse('https://site.com/api/endpoint'),
  headers: headers,
);
```

## Summary

- **LearnPress**: Works immediately, no setup needed
- **LifterLMS**: Requires JWT plugin or app passwords
- **Both platforms**: Unified interface in the app
- **Automatic detection**: App handles platform differences
- **Fallback options**: Multiple auth methods for LifterLMS

The app will guide users through setup if LifterLMS authentication isn't configured properly.