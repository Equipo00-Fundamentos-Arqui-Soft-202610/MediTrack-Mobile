import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String medicationChannelId = 'medication_reminders_channel';
  static const String medicationChannelName = 'Medication Reminders';
  static const String medicationChannelDescription =
      'Notifications for medication dose reminders';

  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _createAndroidNotificationChannel();
    await requestPermissions();
  }

  Future<void> _createAndroidNotificationChannel() async {
    if (!Platform.isAndroid) return;

    const androidChannel = AndroidNotificationChannel(
      medicationChannelId,
      medicationChannelName,
      description: medicationChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
  }

  Future<void> scheduleDailyMedicationNotification({
    required int notificationId,
    required String medicationName,
    required String dose,
    required int hour,
    required int minute,
  }) async {
    final scheduledDate = _nextInstanceOfTime(hour, minute);

    await _plugin.zonedSchedule(
      notificationId,
      '¡Hora de tu dosis!',
      '$medicationName - $dose',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          medicationChannelId,
          medicationChannelName,
          channelDescription: medicationChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          ongoing: true,
          autoCancel: false,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          actions: [
            AndroidNotificationAction(
              'TAKE_DOSE',
              'Tomar dosis',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              'POSTPONE_10',
              'Posponer 10 min',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '$notificationId|$medicationName|$dose',
    );
  }

  /// Muestra de inmediato una notificación con contenido arbitrario. Se usa
  /// para presentar los pushes de FCM que llegan con la app en foreground,
  /// ya que en ese estado FCM no los muestra automáticamente.
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    int notificationId = 0,
  }) async {
    await _plugin.show(
      notificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          medicationChannelId,
          medicationChannelName,
          channelDescription: medicationChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
        ),
      ),
    );
  }

  Future<void> showTestMedicationNotification() async {
    await _plugin.show(
      9999,
      '¡Hora de tu dosis!',
      'Amoxicillin - 500mg',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          medicationChannelId,
          medicationChannelName,
          channelDescription: medicationChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          ongoing: true,
          autoCancel: false,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          actions: [
            AndroidNotificationAction(
              'TAKE_DOSE',
              'Tomar dosis',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              'POSTPONE_10',
              'Posponer 10 min',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: '9999|Amoxicillin|500mg',
    );
  }

  Future<void> cancelNotification(int notificationId) async {
    await _plugin.cancel(notificationId);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  void _onNotificationTap(NotificationResponse response) {
    // Luego podemos usar esto para navegar a una pantalla específica.
    // Por ahora queda preparado.
  }
}
