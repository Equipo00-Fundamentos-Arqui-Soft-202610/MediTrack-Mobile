import 'package:alarm/alarm.dart';

class MedicationAlarmService {
  MedicationAlarmService._();

  static final MedicationAlarmService instance = MedicationAlarmService._();

  Future<void> scheduleMedicationAlarm({
    required int alarmId,
    required String medicationName,
    required String dose,
    required int hour,
    required int minute,
  }) async {
    final alarmDateTime = _nextAlarmDateTime(hour, minute);

    final alarmSettings = AlarmSettings(
      id: alarmId,
      dateTime: alarmDateTime,
      assetAudioPath: 'assets/sounds/medication_alarm.mp3',
      loopAudio: true,
      vibrate: true,
      volumeSettings: const VolumeSettings.fixed(
        volume: 0.8,
        volumeEnforced: true,
      ),
      notificationSettings: NotificationSettings(
        title: '¡Hora de tu dosis!',
        body: '$medicationName - $dose',
        stopButton: 'Tomar dosis',
        icon: 'notification_icon',
      ),
    );

    await Alarm.set(alarmSettings: alarmSettings);
  }

  Future<void> scheduleTestMedicationAlarm() async {
    final alarmDateTime = DateTime.now().add(const Duration(minutes: 1));

    final alarmSettings = AlarmSettings(
      id: 1001,
      dateTime: alarmDateTime,
      assetAudioPath: 'assets/sounds/medication_alarm.mp3',
      loopAudio: true,
      vibrate: true,
      volumeSettings: const VolumeSettings.fixed(
        volume: 0.8,
        volumeEnforced: true,
      ),
      notificationSettings: const NotificationSettings(
        title: '¡Hora de tu dosis!',
        body: 'Amoxicillin - 500mg',
        stopButton: 'Tomar dosis',
        icon: 'notification_icon',
      ),
    );

    await Alarm.set(alarmSettings: alarmSettings);
  }

  Future<void> stopAlarm(int alarmId) async {
    await Alarm.stop(alarmId);
  }

  /// Programa una alarma sonora en un instante exacto (usado por el ciclo
  /// escalonado de recordatorios: alarma inicial + 2 avisos), a diferencia de
  /// [scheduleMedicationAlarm] que solo toma hora:minuto del día actual.
  ///
  /// El paquete `alarm` no permite distinguir por qué dejó de sonar una
  /// alarma (botón, deslizar, timeout), así que su botón se etiqueta como
  /// "Silenciar" y SOLO detiene el sonido — no tiene ningún significado de
  /// negocio. La acción explícita "Tomar dosis" vive por separado en
  /// `LocalNotificationService` (`flutter_local_notifications`, que sí
  /// permite distinguir acciones vía `actionId`).
  Future<void> scheduleAlarmAt({
    required int alarmId,
    required DateTime dateTime,
    required String title,
    required String body,
  }) async {
    final alarmSettings = AlarmSettings(
      id: alarmId,
      dateTime: dateTime,
      assetAudioPath: 'assets/sounds/medication_alarm.mp3',
      loopAudio: true,
      vibrate: true,
      volumeSettings: const VolumeSettings.fixed(
        volume: 0.8,
        volumeEnforced: true,
      ),
      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        stopButton: 'Silenciar',
        icon: 'notification_icon',
      ),
    );

    await Alarm.set(alarmSettings: alarmSettings);
  }

  DateTime _nextAlarmDateTime(int hour, int minute) {
    final now = DateTime.now();

    var alarmDateTime = DateTime(now.year, now.month, now.day, hour, minute);

    if (alarmDateTime.isBefore(now)) {
      alarmDateTime = alarmDateTime.add(const Duration(days: 1));
    }

    return alarmDateTime;
  }
}
