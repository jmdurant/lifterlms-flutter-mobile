import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/backend/services/lms_service.dart';
import 'package:flutter_app/app/helper/router.dart';
import 'package:flutter_app/app/util/toast.dart';
import 'package:get/get.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationController extends GetxController implements GetxService {
  final LMSService lmsService = LMSService.to;
  
  // Firebase messaging
  late FirebaseMessaging _firebaseMessaging;
  late FlutterLocalNotificationsPlugin _localNotifications;
  
  // Notifications list
  final RxList<Map<String, dynamic>> notifications = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> unreadNotifications = <Map<String, dynamic>>[].obs;
  
  // Notification counts
  final RxInt totalNotifications = 0.obs;
  final RxInt unreadCount = 0.obs;
  
  // FCM token
  final RxString fcmToken = ''.obs;
  
  // Notification preferences
  final RxBool pushEnabled = true.obs;
  final RxBool courseUpdates = true.obs;
  final RxBool lessonReminders = true.obs;
  final RxBool quizReminders = true.obs;
  final RxBool assignmentDueDates = true.obs;
  final RxBool gradeNotifications = true.obs;
  final RxBool certificateNotifications = true.obs;
  final RxBool promotionalNotifications = false.obs;
  final RxBool soundEnabled = true.obs;
  final RxBool vibrationEnabled = true.obs;
  
  // Notification categories
  final Map<String, IconData> categoryIcons = {
    'course': Icons.school,
    'lesson': Icons.play_circle_outline,
    'quiz': Icons.quiz,
    'assignment': Icons.assignment,
    'grade': Icons.grade,
    'certificate': Icons.card_membership,
    'achievement': Icons.emoji_events,
    'message': Icons.message,
    'announcement': Icons.announcement,
    'reminder': Icons.access_alarm,
    'promotion': Icons.local_offer,
  };
  
  // UI states
  final RxBool isLoading = false.obs;
  final RxInt selectedFilter = 0.obs; // 0: All, 1: Unread, 2: Course, 3: System
  
  // Pagination
  final RxInt currentPage = 1.obs;
  final RxBool hasMoreNotifications = true.obs;
  final int notificationsPerPage = 20;
  
  ScrollController scrollController = ScrollController();
  late SharedPreferences _prefs;
  
  @override
  void onInit() async {
    super.onInit();
    _prefs = await SharedPreferences.getInstance();
    initializeNotifications();
    loadNotificationPreferences();
    loadStoredNotifications();
    
    // Setup scroll listener for pagination
    scrollController.addListener(() {
      if (scrollController.position.pixels >= 
          scrollController.position.maxScrollExtent - 200) {
        if (!isLoading.value && hasMoreNotifications.value) {
          loadMoreNotifications();
        }
      }
    });
  }
  
  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
  
  /// Initialize notifications
  Future<void> initializeNotifications() async {
    // Skip Firebase on Linux and macOS
    if (Platform.isLinux || Platform.isMacOS) {
      return;
    }
    
    // Initialize Firebase Messaging
    _firebaseMessaging = FirebaseMessaging.instance;
    
    // Initialize local notifications
    _localNotifications = FlutterLocalNotificationsPlugin();
    
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        onNotificationTapped(details.payload);
      },
    );
    
    // Request permissions
    await requestPermissions();
    
    // Get FCM token
    await getFCMToken();
    
    // Setup message handlers
    setupMessageHandlers();
  }
  
  /// Request notification permissions
  Future<void> requestPermissions() async {
    final NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      pushEnabled.value = true;
      print('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      pushEnabled.value = true;
      print('User granted provisional permission');
    } else {
      pushEnabled.value = false;
      print('User declined or has not accepted permission');
    }
  }
  
  /// Get FCM token
  Future<void> getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        fcmToken.value = token;
        await registerFCMToken(token);
      }
      
      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        fcmToken.value = newToken;
        registerFCMToken(newToken);
      });
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }
  
  /// Register FCM token with server
  Future<void> registerFCMToken(String token) async {
    if (!lmsService.isLoggedIn) return;
    
    try {
      // This would need a custom endpoint to register FCM token
      final data = {
        'user_id': lmsService.currentUserId,
        'fcm_token': token,
        'device_type': GetPlatform.isAndroid ? 'android' : 'ios',
      };
      
      // Simulate API call
      await Future.delayed(Duration(seconds: 1));
      
      print('FCM token registered: $token');
    } catch (e) {
      print('Error registering FCM token: $e');
    }
  }
  
  /// Setup message handlers
  void setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      handleMessage(message);
    });
    
    // Background message tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleNotificationTap(message.data);
    });
    
    // Check if app was opened from terminated state
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        handleNotificationTap(message.data);
      }
    });
  }
  
  /// Handle incoming message
  void handleMessage(RemoteMessage message) {
    final notification = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': message.notification?.title ?? 'New Notification',
      'body': message.notification?.body ?? '',
      'category': message.data['category'] ?? 'general',
      'data': message.data,
      'timestamp': DateTime.now().toIso8601String(),
      'read': false,
    };
    
    // Add to notifications list
    notifications.insert(0, notification);
    unreadNotifications.insert(0, notification);
    unreadCount.value++;
    totalNotifications.value++;
    
    // Save to local storage
    saveNotificationLocally(notification);
    
    // Show local notification if app is in foreground
    if (pushEnabled.value) {
      showLocalNotification(notification);
    }
  }
  
  /// Show local notification
  Future<void> showLocalNotification(Map<String, dynamic> notification) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'lifterlms_channel',
      'LifterLMS Notifications',
      channelDescription: 'Notifications for LifterLMS courses',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification['title'],
      notification['body'],
      platformDetails,
      payload: jsonEncode(notification['data']),
    );
  }
  
  /// Handle notification tap
  void handleNotificationTap(Map<String, dynamic> data) {
    final category = data['category'] ?? '';
    final id = data['id'] ?? '';
    
    switch (category) {
      case 'course':
        if (id.isNotEmpty) {
          Get.toNamed(
            AppRouter.getCourseDetail(),
            arguments: {'id': int.parse(id)},
          );
        }
        break;
      case 'lesson':
        if (data['course_id'] != null) {
          Get.toNamed(
            AppRouter.getLearning(),
            arguments: {
              'id': int.parse(data['course_id']),
              'lesson_id': int.parse(id),
            },
          );
        }
        break;
      case 'quiz':
        if (data['course_id'] != null) {
          Get.toNamed(
            AppRouter.getLearning(),
            arguments: {
              'id': int.parse(data['course_id']),
              'quiz_id': int.parse(id),
            },
          );
        }
        break;
      case 'certificate':
        Get.toNamed(AppRouter.profile);
        break;
      case 'achievement':
        Get.toNamed(AppRouter.profile);
        break;
      default:
        // Open notifications page
        break;
    }
  }
  
  /// On notification tapped (local)
  void onNotificationTapped(String? payload) {
    if (payload != null) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        handleNotificationTap(data);
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
  }
  
  /// Load notification preferences
  Future<void> loadNotificationPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    
    pushEnabled.value = _prefs.getBool('push_enabled') ?? true;
    courseUpdates.value = _prefs.getBool('course_updates') ?? true;
    lessonReminders.value = _prefs.getBool('lesson_reminders') ?? true;
    quizReminders.value = _prefs.getBool('quiz_reminders') ?? true;
    assignmentDueDates.value = _prefs.getBool('assignment_due_dates') ?? true;
    gradeNotifications.value = _prefs.getBool('grade_notifications') ?? true;
    certificateNotifications.value = _prefs.getBool('certificate_notifications') ?? true;
    promotionalNotifications.value = _prefs.getBool('promotional_notifications') ?? false;
    soundEnabled.value = _prefs.getBool('sound_enabled') ?? true;
    vibrationEnabled.value = _prefs.getBool('vibration_enabled') ?? true;
  }
  
  /// Save notification preferences
  Future<void> saveNotificationPreferences() async {
    await _prefs.setBool('push_enabled', pushEnabled.value);
    await _prefs.setBool('course_updates', courseUpdates.value);
    await _prefs.setBool('lesson_reminders', lessonReminders.value);
    await _prefs.setBool('quiz_reminders', quizReminders.value);
    await _prefs.setBool('assignment_due_dates', assignmentDueDates.value);
    await _prefs.setBool('grade_notifications', gradeNotifications.value);
    await _prefs.setBool('certificate_notifications', certificateNotifications.value);
    await _prefs.setBool('promotional_notifications', promotionalNotifications.value);
    await _prefs.setBool('sound_enabled', soundEnabled.value);
    await _prefs.setBool('vibration_enabled', vibrationEnabled.value);
    
    showToast('Notification preferences updated');
  }
  
  /// Public method to refresh notifications
  Future<void> loadNotifications() async {
    await loadStoredNotifications();
  }
  
  /// Load stored notifications
  Future<void> loadStoredNotifications() async {
    try {
      isLoading.value = true;
      
      final storedNotifications = _prefs.getStringList('notifications') ?? [];
      
      notifications.clear();
      unreadNotifications.clear();
      
      for (String notificationStr in storedNotifications) {
        try {
          final notification = jsonDecode(notificationStr) as Map<String, dynamic>;
          notifications.add(notification);
          
          if (notification['read'] == false) {
            unreadNotifications.add(notification);
          }
        } catch (e) {
          print('Error parsing stored notification: $e');
        }
      }
      
      totalNotifications.value = notifications.length;
      unreadCount.value = unreadNotifications.length;
      
      // Load from API if logged in
      if (lmsService.isLoggedIn) {
        await loadServerNotifications();
      }
      
    } catch (e) {
      print('Error loading stored notifications: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Load notifications from server
  Future<void> loadServerNotifications() async {
    try {
      // This would need a custom endpoint
      // For now, create sample notifications
      final sampleNotifications = [
        {
          'id': '1',
          'title': 'New Course Available',
          'body': 'Check out our latest course on Advanced Flutter Development',
          'category': 'course',
          'data': {'course_id': '123'},
          'timestamp': DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
          'read': false,
        },
        {
          'id': '2',
          'title': 'Quiz Reminder',
          'body': 'You have a quiz due tomorrow in Web Development Basics',
          'category': 'quiz',
          'data': {'course_id': '456', 'quiz_id': '789'},
          'timestamp': DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
          'read': false,
        },
        {
          'id': '3',
          'title': 'Certificate Earned!',
          'body': 'Congratulations! You\'ve earned a certificate for Python Programming',
          'category': 'certificate',
          'data': {'course_id': '101', 'certificate_id': '202'},
          'timestamp': DateTime.now().subtract(Duration(days: 2)).toIso8601String(),
          'read': true,
        },
      ];
      
      for (var notification in sampleNotifications) {
        if (!notifications.any((n) => n['id'] == notification['id'])) {
          notifications.add(notification);
          if (notification['read'] == false) {
            unreadNotifications.add(notification);
          }
        }
      }
      
      totalNotifications.value = notifications.length;
      unreadCount.value = unreadNotifications.length;
      
    } catch (e) {
      print('Error loading server notifications: $e');
    }
  }
  
  /// Delete FCM token (for logout)
  Future<void> deleteFCMToken(String token) async {
    if (lmsService.isLoggedIn && lmsService.currentUserId != null) {
      try {
        await lmsService.api.unregisterDeviceToken(token: token);
      } catch (e) {
        print('Error unregistering device token: $e');
      }
    }
  }
  
  /// Load more notifications (pagination)
  Future<void> loadMoreNotifications() async {
    if (!hasMoreNotifications.value || isLoading.value) return;
    
    try {
      isLoading.value = true;
      currentPage.value++;
      
      // This would load more from server
      await Future.delayed(Duration(seconds: 1));
      
      // For now, mark as no more notifications
      hasMoreNotifications.value = false;
      
    } catch (e) {
      print('Error loading more notifications: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Save notification locally
  void saveNotificationLocally(Map<String, dynamic> notification) {
    final storedNotifications = _prefs.getStringList('notifications') ?? [];
    storedNotifications.insert(0, jsonEncode(notification));
    
    // Keep only last 100 notifications
    if (storedNotifications.length > 100) {
      storedNotifications.removeRange(100, storedNotifications.length);
    }
    
    _prefs.setStringList('notifications', storedNotifications);
  }
  
  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final index = notifications.indexWhere((n) => n['id'] == notificationId);
    if (index != -1) {
      notifications[index]['read'] = true;
      unreadNotifications.removeWhere((n) => n['id'] == notificationId);
      unreadCount.value = unreadNotifications.length;
      
      // Update local storage
      saveAllNotifications();
    }
  }
  
  /// Mark all as read
  Future<void> markAllAsRead() async {
    for (var notification in notifications) {
      notification['read'] = true;
    }
    
    unreadNotifications.clear();
    unreadCount.value = 0;
    
    // Update local storage
    saveAllNotifications();
    
    showToast('All notifications marked as read');
  }
  
  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    notifications.removeWhere((n) => n['id'] == notificationId);
    unreadNotifications.removeWhere((n) => n['id'] == notificationId);
    
    totalNotifications.value = notifications.length;
    unreadCount.value = unreadNotifications.length;
    
    // Update local storage
    saveAllNotifications();
    
    // Trigger UI update
    update();
  }
  
  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    Get.dialog(
      AlertDialog(
        title: Text('Clear All Notifications'),
        content: Text('Are you sure you want to clear all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              
              notifications.clear();
              unreadNotifications.clear();
              totalNotifications.value = 0;
              unreadCount.value = 0;
              
              // Clear local storage
              await _prefs.remove('notifications');
              
              // Trigger UI update
              update();
            },
            child: Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  /// Save all notifications to local storage
  void saveAllNotifications() {
    final notificationStrings = notifications
        .map((n) => jsonEncode(n))
        .toList();
    
    _prefs.setStringList('notifications', notificationStrings);
  }
  
  /// Filter notifications
  List<Map<String, dynamic>> getFilteredNotifications() {
    switch (selectedFilter.value) {
      case 1: // Unread
        return unreadNotifications;
      case 2: // Course
        return notifications.where((n) => 
          ['course', 'lesson', 'quiz', 'assignment'].contains(n['category'])
        ).toList();
      case 3: // System
        return notifications.where((n) => 
          ['achievement', 'certificate', 'announcement'].contains(n['category'])
        ).toList();
      default: // All
        return notifications;
    }
  }
  
  /// Change filter
  void changeFilter(int filter) {
    selectedFilter.value = filter;
  }
  
  /// Toggle push notifications
  Future<void> togglePushNotifications(bool enabled) async {
    pushEnabled.value = enabled;
    await saveNotificationPreferences();
    
    if (!enabled) {
      // Unregister FCM token
      await unregisterFCMToken();
    } else {
      // Re-register FCM token
      await getFCMToken();
    }
  }
  
  /// Unregister FCM token
  Future<void> unregisterFCMToken() async {
    try {
      // This would need a custom endpoint
      await Future.delayed(Duration(seconds: 1));
      print('FCM token unregistered');
    } catch (e) {
      print('Error unregistering FCM token: $e');
    }
  }
  
  /// Get notification icon
  IconData getNotificationIcon(String category) {
    return categoryIcons[category] ?? Icons.notifications;
  }
  
  /// Format timestamp
  String formatTimestamp(String timestamp) {
    final date = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}