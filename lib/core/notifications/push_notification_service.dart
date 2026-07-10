import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:meditrack_mobile/core/constants/app_constants.dart';
import 'package:meditrack_mobile/core/notifications/local_notification_service.dart';

/// Maneja la suscripción al topic de FCM del paciente (CON-05) y la
/// presentación de los pushes que llegan mientras la app está en foreground
/// (FCM no los muestra automáticamente en ese caso).
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Debe coincidir con `FcmTopicPrefix` + PatientId del backend
    // (ReminderNotificationOptions.cs: "patient_" + reminder.PatientId).
    await _messaging.subscribeToTopic('patient_${AppConstants.patientId}');

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await LocalNotificationService.instance.showImmediateNotification(
      title: notification.title ?? '¡Hora de tu dosis!',
      body: notification.body ?? '',
      notificationId: message.hashCode,
    );
  }

  static Future<void> onBackgroundMessage(RemoteMessage message) async {
    // FCM ya muestra la notificación de sistema cuando la app está en
    // background/terminated; este handler queda disponible para lógica
    // adicional (ej. sincronizar datos) sin bloquear la entrega.
  }
}
