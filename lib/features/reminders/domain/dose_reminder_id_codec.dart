/// Genera IDs determinísticos y únicos para el ciclo de recordatorios de una
/// dosis, combinando:
///   - el "tipo" de entrada (alarma sonora vs. notificación con acción
///     explícita "Tomar dosis" — ver [DoseReminderIdCodec.kindAlarm]/
///     [kindNotification]), para que ambas puedan coexistir sin pisarse
///     mutuamente en el mismo espacio de IDs de Android,
///   - la dosis/schedule (`doseScheduleId`),
///   - la fecha de la ocurrencia (día, no la hora exacta), y
///   - el número de intento (0 = alarma/aviso inicial, 1 = 2do aviso,
///     2 = 3er aviso).
///
/// Tanto el plugin `alarm` como `flutter_local_notifications` usan IDs
/// `Int32` (Kotlin `Int`) del lado nativo de Android, así que el resultado
/// se mantiene siempre por debajo de ese límite. `doseScheduleId` y el día se
/// reducen con módulo para caber en el presupuesto de dígitos — una colisión
/// requeriría que dos `doseScheduleId` distintos coincidan exactamente módulo
/// 10000 y caigan en el mismo día módulo 10000, algo sin relevancia práctica
/// en la escala de esta app.
class DoseReminderIdCodec {
  DoseReminderIdCodec._();

  static const int initialAttempt = 0;
  static const int secondAttempt = 1;
  static const int thirdAttempt = 2;

  /// Namespace de las alarmas sonoras (`alarm` package).
  static const int kindAlarm = 0;

  /// Namespace de las notificaciones con acción explícita "Tomar dosis"
  /// (`flutter_local_notifications`). Separado del namespace de alarmas para
  /// que ambos plugins puedan tener, para el mismo intento, un ID de
  /// notificación de Android propio sin sobrescribirse entre sí.
  static const int kindNotification = 1;

  static final DateTime _epoch = DateTime.utc(2024, 1, 1);

  /// Construye el ID de un elemento (alarma o notificación) para el
  /// [attempt] (0, 1 o 2) de la ocurrencia de [doseScheduleId] programada en
  /// [scheduledAtUtc]. [kind] selecciona el namespace ([kindAlarm] por
  /// defecto).
  static int build({
    required int doseScheduleId,
    required DateTime scheduledAtUtc,
    required int attempt,
    int kind = kindAlarm,
  }) {
    assert(attempt >= initialAttempt && attempt <= thirdAttempt);
    assert(kind == kindAlarm || kind == kindNotification);

    final epochDay = scheduledAtUtc.toUtc().difference(_epoch).inDays;
    final safeDoseScheduleId = doseScheduleId.abs() % 10000;
    final safeDayBucket = epochDay.abs() % 10000;

    return kind * 1000000000 +
        safeDoseScheduleId * 100000 +
        safeDayBucket * 10 +
        attempt +
        1;
  }

  /// Los 3 IDs del ciclo completo para el namespace [kind], en orden
  /// [inicial, 2do aviso, 3er aviso].
  static List<int> buildCycle({
    required int doseScheduleId,
    required DateTime scheduledAtUtc,
    int kind = kindAlarm,
  }) {
    return [
      build(
        doseScheduleId: doseScheduleId,
        scheduledAtUtc: scheduledAtUtc,
        attempt: initialAttempt,
        kind: kind,
      ),
      build(
        doseScheduleId: doseScheduleId,
        scheduledAtUtc: scheduledAtUtc,
        attempt: secondAttempt,
        kind: kind,
      ),
      build(
        doseScheduleId: doseScheduleId,
        scheduledAtUtc: scheduledAtUtc,
        attempt: thirdAttempt,
        kind: kind,
      ),
    ];
  }
}
