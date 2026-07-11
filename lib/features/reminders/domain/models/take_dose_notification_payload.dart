/// Codifica/decodifica el payload de la notificación con la acción explícita
/// "Tomar dosis" (`flutter_local_notifications`), que debe identificar de
/// forma segura la dosis/ocurrencia y qué alarma sonora puntual corresponde
/// detener (sin afectar las de los avisos siguientes).
class TakeDoseNotificationPayload {
  final int doseScheduleId;
  final DateTime scheduledAtUtc;
  final int alarmId;

  const TakeDoseNotificationPayload({
    required this.doseScheduleId,
    required this.scheduledAtUtc,
    required this.alarmId,
  });

  String encode() =>
      '$doseScheduleId|${scheduledAtUtc.toUtc().toIso8601String()}|$alarmId';

  static TakeDoseNotificationPayload? tryParse(String? payload) {
    if (payload == null) return null;

    final parts = payload.split('|');
    if (parts.length != 3) return null;

    final doseScheduleId = int.tryParse(parts[0]);
    final scheduledAtUtc = DateTime.tryParse(parts[1])?.toUtc();
    final alarmId = int.tryParse(parts[2]);
    if (doseScheduleId == null || scheduledAtUtc == null || alarmId == null)
      return null;

    return TakeDoseNotificationPayload(
      doseScheduleId: doseScheduleId,
      scheduledAtUtc: scheduledAtUtc,
      alarmId: alarmId,
    );
  }
}
