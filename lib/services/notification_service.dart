import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watertracker/widgets/custom_notification_widget.dart';
export 'package:watertracker/widgets/custom_notification_widget.dart' show NotificationType;

import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:math';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  OverlayEntry? _overlayEntry;

  Future<void> init() async {
    print('NotificationService.init() started');
    try {
      try {
        final String timeZoneName = await FlutterTimezone.getLocalTimezone();
        tz.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        print('Timezones initialized: $timeZoneName');
      } catch (e) {
        print('Timezone initialization error: $e');
        // Fallback to UTC or don't set location
        tz.initializeTimeZones();
      }

      if (!kIsWeb) {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');

        final DarwinInitializationSettings initializationSettingsDarwin =
            DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        );

        final InitializationSettings initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

        await flutterLocalNotificationsPlugin.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: (details) {
            // Handle notification tap
          },
        );
        print('Local notifications initialized');

        final AndroidNotificationChannel channel = AndroidNotificationChannel(
          'water_reminder_channel',
          'Water Reminders',
          description: 'Reminders to drink water',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
          enableLights: true,
          showBadge: true,
        );

        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
        print('Android notification channel created and configured');
      } else {
        print('Platform is Web, skipping mobile-only local notification setup');
      }

      // Setup Firebase Messaging (Don't let it block the entire app if it fails)
      try {
        print('Attempting Firebase Messaging setup...');
        await _setupFirebaseMessaging();
        print('Firebase Messaging setup finished');
      } catch (e) {
        print('Firebase Messaging setup error: $e');
      }
    } catch (e) {
      print('Error during NotificationService.init(): $e');
    }
    print('NotificationService.init() complete');
  }

  Future<void> _setupFirebaseMessaging() async {
    // Moved permission request to be UI driven


    // Background messaging is mostly for mobile or specific web setup
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      if (message.notification != null) {
        _showNativeNotification(
          message.notification!.hashCode,
          message.notification!.title ?? 'New Notification',
          message.notification!.body ?? '',
        );
      }
    });
  }

  Future<NotificationDetails> _getNotificationDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final soundSetting = prefs.getString('selected_sound') ?? 'Dering';

    bool playSound = true;
    bool enableVibration = true;
    Importance importance = Importance.max;
    Priority priority = Priority.high;

    // Default to Dering logic
    playSound = true;
    enableVibration = true;
    importance = Importance.max;
    priority = Priority.high;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        'water_reminder_channel',
        'Water Reminders',
        channelDescription: 'Reminders to drink water',
        importance: Importance.max,
        priority: Priority.max,
        playSound: playSound,
        enableVibration: enableVibration,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: playSound,
      ),
    );
  }

  Future<void> _showNativeNotification(int id, String title, String body) async {
    final details = await _getNotificationDetails();
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      details,
    );
  }

  Future<void> requestPermissions() async {
    // Request Local Notification Permissions
    // Request Exact Alarm Permissions (Android 13+)
    try {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
      }
    } catch (e) {
      print('Android permission request error: $e');
    }
        
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Request Firebase Messaging Permissions
    try {
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        provisional: false,
        sound: true,
      );
    } catch (e) {
      print('Firebase Messaging permission request error: $e');
    }
  }

  Future<void> scheduleRemindersList(dynamic reminders) async {
    if (kIsWeb) {
      print('Platform is Web, skipping local notification scheduling');
      return;
    }
    
    await cancelAll();
    int id = 0;

    final List<Map<String, String>> templates = [
      {
        'title': 'Minum dulu ga sih 😗',
        'body': 'Sedikit air sekarang, fokus lebih stabil nanti. SipSip nemenin kamu kok.'
      },
      {
        'title': 'Teman-sip dateng~',
        'body': 'Aku ngingetin dengan lembut yaa, jangan lupa minum air \u2665'
      },
      {
        'title': 'Waktunya rehat sebentar \ud83d\udca7',
        'body': 'Satu dua teguk air bisa bantu badan kamu lebih siap lanjut lagi.'
      },
      {
        'title': 'Hari ini panas banget gak sih, Teman-sip? \ud83e\udd75',
        'body': 'Yuk minum dulu sebentar, biar badan kamu tetap seger dan ga ikut kepanasan \ud83d\ude09'
      },
      {
        'title': 'Bestie check \ud83d\udca6',
        'body': 'SipSip mau pastiin kamu ga lupa minum hari ini.'
      },
    ];

    final random = Random();

    for (var reminder in reminders) {
      String time;
      if (reminder is Map) {
        time = reminder['time'];
      } else {
        time = reminder.time;
      }
      
      final timeParts = time.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // Pick a random template
      final template = templates[random.nextInt(templates.length)];
      
      String title = template['title']!;
      String body = template['body']!;

      // Custom logic: If it's the first reminder and we want to show the goal (mocked example)
      if (id == 0) {
        title = '\ud83d\udca7 Target minum harianmu sedang menanti!';
        body = 'Air membantu kamu untuk terus semangat menjalani harimu. Tingkatkan fokusmu dengan minum air yang cukup Teman-sip! \ud83d\ude09';
      }
      
      await _scheduleDailyNotification(
        id++,
        title,
        body,
        TimeOfDay(hour: hour, minute: minute),
      );
    }
  }

  Future<void> _scheduleDailyNotification(
      int id, String title, String body, TimeOfDay time) async {
    final details = await _getNotificationDetails();
    final scheduledTime = _nextInstanceOfTime(time);
    print('DEBUG: Scheduling ID: $id at $scheduledTime (Current local time: ${tz.TZDateTime.now(tz.local)})');
    
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      print('DEBUG: Successfully scheduled ID: $id');
    } catch (e) {
      print('DEBUG: Error scheduling ID: $id - $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    
    // Add 10 seconds buffer to avoid scheduling in the very immediate past/present
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> rescheduleAllReminders() async {
    if (kIsWeb) return;

    print('Attempting to reschedule all reminders from storage');
    await requestPermissions();
    
    final prefs = await SharedPreferences.getInstance();
    final List<String>? storedReminders = prefs.getStringList('reminders_list');
    
    if (storedReminders != null && storedReminders.isNotEmpty) {
      try {
        final List<dynamic> reminders = storedReminders
            .map((s) => jsonDecode(s))
            .toList();
        
        await scheduleRemindersList(reminders);
        print('Notifications rescheduled successfully (${reminders.length} reminders)');
      } catch (e) {
        print("Error rescheduling notifications: $e");
      }
    } else {
      print('No stored reminders found to reschedule');
    }
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // --- In-App Overlay Notification ---
  void showInAppNotification(BuildContext context, NotificationType type) {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: CustomNotificationWidget(type: type),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    Future.delayed(const Duration(seconds: 3), () {
      hideInAppNotification();
    });
  }

  void hideInAppNotification() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  // --- Testing Methods ---
  Future<void> showInstantTestNotification() async {
    await _showNativeNotification(
      999,
      'Test Notifikasi 🧪',
      'Ini adalah notifikasi instan untuk mengecek suara dan getaran.',
    );
  }

  Future<void> scheduleTestNotification(int seconds) async {
    await requestPermissions();
    final details = await _getNotificationDetails();
    final scheduledTime = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    
    print('Scheduling test notification in $seconds seconds at $scheduledTime');
    
    await flutterLocalNotificationsPlugin.zonedSchedule(
      998,
      'Test Alaram ⏰',
      'Ini adalah notifikasi terjadwal ($seconds detik) untuk mengecek fungsi alaram.',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<List<String>> getPendingNotifications() async {
    final List<PendingNotificationRequest> pending =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    return pending.map((p) => '[ID:${p.id}] ${p.title}').toList();
  }
}
