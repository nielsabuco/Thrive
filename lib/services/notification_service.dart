import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // Create high-importance alarm channel for Android
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'thrive_alarms_channel',
        'Thrive Reminders & Alarms',
        description: 'Exact alarm alerts for your daily reminders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

      await androidImplementation.createNotificationChannel(channel);
    }

    _isInitialized = true;
  }

  /// Request permissions specifically
  Future<bool> requestPermissions() async {
    final android = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final notifGranted = await android.requestNotificationsPermission();
      final exactAlarmGranted = await android.requestExactAlarmsPermission();
      return (notifGranted ?? false) && (exactAlarmGranted ?? false);
    }
    return true;
  }

  /// Schedule an exact alarm notification for a reminder
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String category,
    required DateTime date,
    required TimeOfDay time,
    required String repeat,
  }) async {
    await initialize();

    // Calculate the target DateTime
    DateTime scheduledDate = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    final now = DateTime.now();

    // If repeat is 'Daily' and time has passed today, schedule for next occurrence
    if (scheduledDate.isBefore(now)) {
      if (repeat == 'Daily') {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      } else if (repeat == 'Weekly') {
        scheduledDate = scheduledDate.add(const Duration(days: 7));
      } else {
        // One-time reminder that is already in the past; do not alarm
        return;
      }
    }

    final tz.TZDateTime tzScheduledDate =
        tz.TZDateTime.from(scheduledDate, tz.local);

    DateTimeComponents? matchComponents;
    if (repeat == 'Daily') {
      matchComponents = DateTimeComponents.time;
    } else if (repeat == 'Weekly') {
      matchComponents = DateTimeComponents.dayOfWeekAndTime;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'thrive_alarms_channel',
      'Thrive Reminders & Alarms',
      channelDescription: 'Exact alarm alerts for your daily reminders',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        '⏰ Reminder: $title',
        '[$category] It is time for your reminder! Stay focused and thrive.',
        tzScheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
      );
      debugPrint('Scheduled alarm for $title at $tzScheduledDate (ID: $id)');
    } catch (e) {
      debugPrint('Error scheduling exact alarm: $e');
    }
  }

  /// Cancel a scheduled reminder
  Future<void> cancelReminder(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }

  /// Send an immediate test notification so user can test sound & vibration on their device
  Future<void> showTestNotification() async {
    await initialize();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'thrive_alarms_channel',
      'Thrive Reminders & Alarms',
      channelDescription: 'Exact alarm alerts for your daily reminders',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.show(
      999999,
      '⏰ THRIVE Alarm Test',
      'Exact alarms and notifications are active and working!',
      notificationDetails,
    );
  }
}
