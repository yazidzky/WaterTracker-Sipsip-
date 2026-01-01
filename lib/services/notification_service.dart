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

import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  print('notification(${notificationResponse.id}) action tapped: '
      '${notificationResponse.actionId} with payload: ${notificationResponse.payload}');
  if (notificationResponse.actionId == 'stop_alarm') {
    NotificationService().cancelNotification(notificationResponse.id ?? 0);
  }
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
            print('Foreground notification tapped: ${details.payload}');
            // Always cancel the notification to stop the insistent sound
            if (details.id != null) {
              cancelNotification(details.id!);
            }
          },
          onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
        );
        print('Local notifications initialized');

        final AndroidNotificationChannel channel = AndroidNotificationChannel(
          'water_reminder_channel_v2', // Changed ID to apply new settings
          'Water Reminders',
          description: 'Reminders to drink water',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]), // Longer vibration
          enableLights: true,
          showBadge: true,
          audioAttributesUsage: AudioAttributesUsage.alarm, // Critical for bypassing silent mode
        );

        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
        print('Android notification channel created and configured (v2)');
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
    try {
      await rescheduleAllReminders();
    } catch (e) {
      print('Reschedule on init error: $e');
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
        'water_reminder_channel_v2', // Updated ID
        'Water Reminders',
        channelDescription: 'Reminders to drink water',
        importance: Importance.max,
        priority: Priority.max,
        playSound: playSound,
        enableVibration: enableVibration,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        visibility: NotificationVisibility.public, // Show on lock screen
        additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT = 4
        styleInformation: const BigTextStyleInformation(''),
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'stop_alarm',
            'Matikan',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: playSound,
        interruptionLevel: InterruptionLevel.critical, // Try to break through focus modes
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
    try {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      // Check and request SCHEDULE_EXACT_ALARM permission for Android 12+
      if (await Permission.scheduleExactAlarm.isDenied) {
         print('Requesting scheduleExactAlarm permission');
         await Permission.scheduleExactAlarm.request();
      }

      await androidImplementation?.requestExactAlarmsPermission();

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

    // Request Battery Optimization Ignore (Critical for reliable alarms)
    try {
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
         print('Requesting ignoreBatteryOptimizations permission');
         await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (e) {
      print('Battery optimization request error: $e');
    }

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
    try {
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
    } catch (e) {
      print('CRITICAL ERROR in scheduleRemindersList: $e');
      // Do not throw, keep silent to avoid crashing UI/Update Failed msg?
      // Or throw if we want UI to know? The UI shows "Update Gagal" if this fails.
      // But we handled inner errors. If cancelAll fails, that's bad.
      // Re-throwing allows valid failure feedback, but let's log it heavily.
      rethrow; 
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
      print('DEBUG: Successfully scheduled ID: $id (Exact)');
    } catch (e) {
      print('DEBUG: Error scheduling exact alarm ID: $id - $e');
      // Fallback to Inexact Alarm if Exact is denied or fails
      try {
        print('DEBUG: Attempting fallback to Inexact Alarm for ID: $id');
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledTime,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        print('DEBUG: Successfully scheduled ID: $id (Inexact Fallback)');
      } catch (e2) {
        print('DEBUG: Error scheduling inexact fallback ID: $id - $e2');
      }
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

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
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
