import 'package:meditrack_mobile/core/constants/app_constants.dart';

/// Estado persistido localmente del ciclo de recordatorios de UNA ocurrencia
/// de dosis (identificada por [doseScheduleId] + [scheduledAtUtc]): alarma
/// inicial + 2 avisos + cierre a T+10 si el paciente nunca actúa.
///
/// Se persiste (ver `DoseReminderStorage`) para poder reconstruir y cancelar
/// las alarmas/notificaciones ya programadas tras cerrar y reabrir la app o
/// reiniciar el dispositivo — las alarmas nativas (`alarm` package) y las
/// notificaciones (`flutter_local_notifications`) sobreviven por sí solas,
/// pero este modelo es lo que permite al coordinador saber QUÉ programó y en
/// qué estado quedó cada ciclo.
class DoseReminderCycle {
  final int patientId;
  final int doseScheduleId;

  /// Instante exacto (UTC) de esta ocurrencia — junto con [doseScheduleId]
  /// identifica de forma única el ciclo (distingue el mismo horario en días
  /// distintos).
  final DateTime scheduledAtUtc;
  final String medicationName;
  final String dose;

  /// IDs deterministas de las 3 alarmas sonoras de este ciclo (sin
  /// significado de negocio: solo sonido), en orden [inicial, 2do, 3er aviso].
  final List<int> alarmIds;

  /// IDs deterministas de las 3 notificaciones con la acción explícita
  /// "Tomar dosis" (`flutter_local_notifications`), mismo orden que
  /// [alarmIds] y disparadas en los mismos instantes.
  final List<int> notificationIds;

  /// true una vez que el ciclo terminó de resolverse (evidencia enviada,
  /// backend confirmó pendingvalidation/approved/taken/skipped, o venció el
  /// plazo) y ya no debe seguir procesándose.
  final bool closed;

  const DoseReminderCycle({
    required this.patientId,
    required this.doseScheduleId,
    required this.scheduledAtUtc,
    required this.medicationName,
    required this.dose,
    required this.alarmIds,
    this.notificationIds = const [],
    this.closed = false,
  });

  DateTime get secondAlarmAtUtc => scheduledAtUtc.add(
    const Duration(minutes: AppConstants.doseReminderSecondAlarmOffsetMinutes),
  );

  DateTime get thirdAlarmAtUtc => scheduledAtUtc.add(
    const Duration(minutes: AppConstants.doseReminderThirdAlarmOffsetMinutes),
  );

  /// Momento en que, si no hubo ninguna acción del paciente, el ciclo se da
  /// por cerrado localmente (el registro definitivo de "no tomada" lo hace
  /// `StaleDoseExpirationService` en FollowUp-Service, no el mobile).
  DateTime get closeAtUtc => scheduledAtUtc.add(
    const Duration(minutes: AppConstants.doseReminderCloseOffsetMinutes),
  );

  /// Clave estable que identifica esta ocurrencia (dosis/schedule + fecha),
  /// usada como key de persistencia y para comparar "¿es la misma dosis de
  /// antes o una nueva ocurrencia?".
  String get occurrenceKey =>
      '$doseScheduleId@${scheduledAtUtc.toIso8601String()}';

  bool isDue(DateTime nowUtc) => !nowUtc.isBefore(closeAtUtc);

  DoseReminderCycle copyWith({bool? closed}) {
    return DoseReminderCycle(
      patientId: patientId,
      doseScheduleId: doseScheduleId,
      scheduledAtUtc: scheduledAtUtc,
      medicationName: medicationName,
      dose: dose,
      alarmIds: alarmIds,
      notificationIds: notificationIds,
      closed: closed ?? this.closed,
    );
  }

  Map<String, dynamic> toJson() => {
    'patientId': patientId,
    'doseScheduleId': doseScheduleId,
    'scheduledAtUtc': scheduledAtUtc.toIso8601String(),
    'medicationName': medicationName,
    'dose': dose,
    'alarmIds': alarmIds,
    'notificationIds': notificationIds,
    'closed': closed,
  };

  factory DoseReminderCycle.fromJson(Map<String, dynamic> json) {
    return DoseReminderCycle(
      patientId: json['patientId'] as int,
      doseScheduleId: json['doseScheduleId'] as int,
      scheduledAtUtc: DateTime.parse(json['scheduledAtUtc'] as String).toUtc(),
      medicationName: json['medicationName'] as String,
      dose: json['dose'] as String,
      alarmIds: (json['alarmIds'] as List).map((e) => e as int).toList(),
      notificationIds: (json['notificationIds'] as List? ?? const [])
          .map((e) => e as int)
          .toList(),
      closed: json['closed'] as bool? ?? false,
    );
  }
}
