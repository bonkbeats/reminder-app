import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initializeNotifications() async {
    // Initialize timezone database - required for tz package
    // tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Create notification channel explicitly for Android >= 8.0 (API 26+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'reminder_channel_id', // id
      'Expiry Reminder', // title
      description: 'Reminds 30 days before expiry',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // Create the channel
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print('Notification plugin initialized and channel created successfully.');
  }

  static Future<void> scheduleReminder(DateTime scheduledDate,
      {String? title, String? body}) async {
    try {
      // Calculate the reminder date (30 days before the scheduled date)
      final reminderDate = scheduledDate.subtract(const Duration(days: 30));

      final location = tz.getLocation('Asia/Kolkata');
      final tzScheduledDate = tz.TZDateTime.from(reminderDate, location);

      // Ensure the scheduled notification time is in the future
      final now = tz.TZDateTime.now(location);
      if (tzScheduledDate.isBefore(now)) {
        print('Cannot schedule notification in the past: $tzScheduledDate');
        return;
      }

      const androidDetails = AndroidNotificationDetails(
        'reminder_channel_id',
        'Expiry Reminder',
        channelDescription: 'Reminds 30 days before expiry',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      final notifTitle = title ?? 'Expiry Date Reminder';
      final notifBody =
          body ?? 'Your item expires on: ${scheduledDate.toLocal()}';

      print('Scheduling notification for: $tzScheduledDate');
      print('Current time: $now');
      print('Scheduled time: $tzScheduledDate');

      final notificationId =
          DateTime.now().millisecondsSinceEpoch ~/ 1000; // Unique ID
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        notifTitle,
        notifBody,
        tzScheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('Notification scheduled.');
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  // This method can now be removed since we can use scheduleReminder for test notifications
  // static Future<void> testNotification() async {
  //   try {
  //     const androidDetails = AndroidNotificationDetails(
  //       'reminder_channel_id',
  //       'Expiry Reminder',
  //       channelDescription: 'Reminds 30 days before expiry',
  //       importance: Importance.max,
  //       priority: Priority.high,
  //       playSound: true,
  //       enableVibration: true,
  //     );

  //     const notificationDetails = NotificationDetails(android: androidDetails);

  //     await _flutterLocalNotificationsPlugin.show(
  //       0,
  //       'Test Notification',
  //       'This is a test notification.',
  //       notificationDetails,
  //     );
  //     print('Test notification sent.');
  //   } catch (e) {
  //     print('Error sending test notification: $e');
  //   }
  // }
}
