import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:meditrack_mobile/core/alarms/medication_alarm_service.dart';
import 'package:meditrack_mobile/features/reminders/data/pending_dose_action_store.dart';
import 'package:meditrack_mobile/features/reminders/domain/models/take_dose_notification_payload.dart';

/// Procesa el toque de la acción explícita "Tomar dosis" (`actionId ==
/// [LocalNotificationService.takeDoseActionId]`): detiene ÚNICAMENTE la
/// alarma sonora de este intento puntual (no las de los avisos siguientes) y
/// persiste la solicitud de abrir la evidencia de esta dosis para que Home
/// la recoja al cargar. No marca nada como tomado ni cancela el ciclo — eso
/// solo ocurre cuando el video se envía con éxito.
///
/// Es una función de nivel superior (no un método de instancia) porque tanto
/// el callback en foreground como el de background/app terminada
/// (`onDidReceiveBackgroundNotificationResponse`) deben poder invocarla sin
/// depender de un objeto ya construido en su isolate.
Future<void> _handleNotificationResponse(NotificationResponse response) async {
  if (response.actionId != LocalNotificationService.takeDoseActionId) return;

  final payload = TakeDoseNotificationPayload.tryParse(response.payload);
  if (payload == null) return;

  await MedicationAlarmService.instance.stopAlarm(payload.alarmId);
  await PendingDoseActionStore.persist(
    doseScheduleId: payload.doseScheduleId,
    scheduledAtUtc: payload.scheduledAtUtc,
  );
}

/// Callback de segundo plano de `flutter_local_notifications`: corre en un
/// isolate propio cuando la app está terminada o completamente en background,
/// así que no puede compartir estado en memoria con la UI — de ahí que
/// [_handleNotificationResponse] persista en disco en lugar de notificar
/// directamente a algún controlador.
@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: discarded_futures
  _handleNotificationResponse(response);
}

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String medicationChannelId = 'medication_reminders_channel';
  static const String medicationChannelName = 'Medication Reminders';
  static const String medicationChannelDescription =
      'Notifications for medication dose reminders';

  /// `actionId` de la acción explícita "Tomar dosis" — la única acción que
  /// tiene efecto de negocio (abrir la evidencia). Detener la notificación
  /// por cualquier otro medio (deslizar, descartar, o el botón "Silenciar"
  /// de la alarma sonora en `MedicationAlarmService`) no dispara nada.
  static const String takeDoseActionId = 'TAKE_DOSE';

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
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationResponse,
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
      // Requerido en Android 12+ (API 31+) para que las alarmas del ciclo de
      // recordatorios (`alarm` package) suenen en el horario exacto en lugar
      // de degradarse a una entrega aproximada por el sistema.
      await Permission.scheduleExactAlarm.request();
    }
  }

  /// Programa, para UN intento puntual del ciclo escalonado de recordatorios
  /// (inicial/2do/3er aviso), una notificación con la acción explícita
  /// "Tomar dosis" — separada de la alarma sonora (`MedicationAlarmService`)
  /// porque el paquete `alarm` no permite distinguir acciones. A diferencia
  /// de [scheduleDailyMedicationNotification], esta NO se repite a diario:
  /// es un evento único para esta ocurrencia de dosis.
  Future<void> scheduleDoseReminderNotification({
    required int notificationId,
    required String title,
    required String medicationName,
    required String dose,
    required DateTime dateTime,
    required int doseScheduleId,
    required DateTime scheduledAtUtc,
    required int alarmId,
  }) async {
    await _plugin.zonedSchedule(
      notificationId,
      title,
      '$medicationName - $dose',
      tz.TZDateTime.from(dateTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          medicationChannelId,
          medicationChannelName,
          channelDescription: medicationChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          playSound: false,
          enableVibration: false,
          category: AndroidNotificationCategory.reminder,
          actions: const [
            AndroidNotificationAction(
              takeDoseActionId,
              'Tomar dosis',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: TakeDoseNotificationPayload(
        doseScheduleId: doseScheduleId,
        scheduledAtUtc: scheduledAtUtc,
        alarmId: alarmId,
      ).encode(),
    );
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

  /// Recupera la respuesta de notificación que lanzó la app desde estado
  /// terminado (si aplica). Necesario porque, en ese caso, ni
  /// `onDidReceiveNotificationResponse` ni el callback de background llegan
  /// a dispararse a tiempo — Android entrega el toque como "detalles de
  /// lanzamiento" en su lugar.
  Future<NotificationAppLaunchDetails?> getLaunchDetails() {
    return _plugin.getNotificationAppLaunchDetails();
  }

  /// Procesa (si aplica) la respuesta de notificación que lanzó la app desde
  /// estado terminado, persistiendo la solicitud de "Tomar dosis" igual que
  /// el callback en vivo. Debe llamarse una vez en el arranque, antes de que
  /// Home cargue datos.
  Future<void> handleColdStartLaunch() async {
    final details = await getLaunchDetails();
    final response = details?.notificationResponse;
    if (details?.didNotificationLaunchApp == true && response != null) {
      await _handleNotificationResponse(response);
    }
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
    // ignore: discarded_futures
    _handleNotificationResponse(response);
  }
}
