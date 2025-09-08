import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_app/app/controller/lifterlms/home_controller.dart';
import 'package:flutter_app/app/controller/lifterlms/notification_controller.dart';
import 'package:flutter_app/app/helper/shared_pref.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_local_controller.dart';
import '../helper/router.dart';

// Background message handler must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
  
  // You can show a notification here if needed
  // But don't try to access GetX controllers as they won't be available
}

class FirebaseApiController extends GetxController {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final _firebaseMessaging = FirebaseMessaging.instance;

  @override
  void initState() {
    NotificationLocalController.initialize(flutterLocalNotificationsPlugin);
  }

  Future<void> initNotifications() async {
    String fCMToken = '';
    
    try {
      await _firebaseMessaging.requestPermission();
      fCMToken = await _firebaseMessaging.getToken() ?? '';
    } catch (e) {
      print('Firebase messaging error: $e');
      // Continue without FCM if it fails
    }
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Register FCM token if available
    if (fCMToken.isNotEmpty) {
      prefs.setString(SharedPreferencesManager.keyFcmToken, fCMToken);
      
      HomeController homeController = Get.find<HomeController>();
      
      String? oldFcmToken = prefs.getString(SharedPreferencesManager.keyFcmToken);
      if (fCMToken != oldFcmToken) {
        if (prefs.getInt('uid') != null) {
          NotificationController notificationController = Get.find<NotificationController>();
          notificationController.deleteFCMToken(oldFcmToken ?? '');
          await notificationController.registerFCMToken(fCMToken);
        }
      }
    }
    
    bool isBadge = await AppBadgePlus.isSupported();
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        HomeController homeController = Get.find<HomeController>();
        if (isBadge) {
          int numberBadge = (prefs.getInt("notify-numbed") ?? 0) + 1;
          prefs.setInt("notify-numbed", numberBadge);
          homeController.updateShowNotification('true');
          AppBadgePlus.updateBadge(numberBadge);
        }
        
        NotificationLocalController.showBigTextNotification(
            id: 123,
            title: message.notification!.title ?? 'No Title',
            body: message.notification!.body ?? 'No Body',
            payload: message.data.toString(),
            fln: flutterLocalNotificationsPlugin);
      }
    });
    
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      Get.toNamed(AppRouter.getNotificationRoute(), preventDuplicates: false);
    });

    // Check for initial message
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        // Handle initial message if needed
        Get.toNamed(AppRouter.getNotificationRoute(), preventDuplicates: false);
      }
    });
  }
}