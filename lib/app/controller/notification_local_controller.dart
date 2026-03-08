import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationLocalController {
  static Future initialize(
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
    var androidInitialize = AndroidInitializationSettings(
        'mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    var linuxInitialize = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );
    var initializationsSettings = InitializationSettings(
        android: androidInitialize,
        iOS: initializationSettingsDarwin,
        linux: linuxInitialize);
    await flutterLocalNotificationsPlugin.initialize(initializationsSettings);
  }

  static Future showBigTextNotification(
      {var id = 0, required String title, required String body,
        var payload, required FlutterLocalNotificationsPlugin fln
      }) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'you_can_name_it_whatever1',
      'channel_name',
      playSound: true,
      //sound: RawResourceAndroidNotificationSound('notification'),
      importance: Importance.max,
      priority: Priority.high,
    );

    var not = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: const DarwinNotificationDetails()
    );
    await fln.show(0, title, body, not);
  }

}