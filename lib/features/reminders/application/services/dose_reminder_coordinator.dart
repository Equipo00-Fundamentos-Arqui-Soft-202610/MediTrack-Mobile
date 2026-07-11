import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:meditrack_mobile/core/alarms/medication_alarm_service.dart';
import 'package:meditrack_mobile/core/constants/app_constants.dart';
import 'package:meditrack_mobile/core/notifications/local_notification_service.dart';
import 'package:meditrack_mobile/features/home/data/models/next_dose_model.dart';
import 'package:meditrack_mobile/features/home/data/services/home_service.dart';
import 'package:meditrack_mobile/features/reminders/data/dose_reminder_storage.dart';
import 'package:meditrack_mobile/features/reminders/domain/dose_reminder_id_codec.dart';
import 'package:meditrack_mobile/features/reminders/domain/models/dose_reminder_cycle.dart';
import 'package:meditrack_mobile/features/reminders/domain/models/missed_dose_snapshot.dart';

/// Coordina el ciclo escalonado de recordatorios de una dosis (alarma
/// inicial + 2 avisos, T+0/T+4/T+7, cierre a T+10) de punta a punta:
/// programar, cancelar y reconciliar contra el backend.
///
/// Reglas de negocio deliberadas (ver informe de la revisión de este
/// diseño):
/// - Detener/silenciar una alarma sonora NUNCA cancela nada ni marca nada:
///   el paquete `alarm` no permite distinguir por qué dejó de sonar, así que
///   no se le atribuye ningún significado. Esta clase NO escucha
///   `Alarm.ringing`.
/// - La única acción con efecto de negocio es la acción explícita "Tomar
///   dosis" de la notificación (`flutter_local_notifications`, `actionId`
///   real) o el botón homónimo en Home — y ninguna de las dos cancela avisos
///   por sí sola, solo abren la pantalla de evidencia.
/// - Los avisos restantes solo se cancelan cuando el backend confirma
///   evidencia real (envío exitoso de video, o `next-dose` deja de reportar
///   la ocurrencia porque quedó `pendingvalidation`/`approved`/`taken`/
///   `skipped`).
/// - El registro definitivo de "no tomada" (`skipped`) en FollowUp-Service
///   lo hace `StaleDoseExpirationService` (backend), NO el mobile — evita
///   una carrera de doble escritura contra el mismo endpoint sin índice
///   único. El mobile solo refleja localmente lo que el backend ya confirmó.
///
/// Toda la lógica temporal vive aquí (no en HomeScreen ni en ningún widget):
/// los timers de reconciliación pertenecen a esta instancia singleton,
/// inicializada una sola vez desde `main.dart`, así que siguen vivos aunque
/// HomeScreen no esté montada. Las alarmas/notificaciones en sí sobreviven
/// al cierre del proceso y a reinicios del dispositivo por su cuenta; lo que
/// este coordinador reconstruye al reiniciar es su propio conocimiento de
/// qué programó y en qué estado quedó cada ciclo.
class DoseReminderCoordinator extends ChangeNotifier {
  DoseReminderCoordinator._({
    required MedicationAlarmService alarmService,
    required LocalNotificationService notificationService,
    required DoseReminderStorage storage,
    required HomeService homeService,
  }) : _alarmService = alarmService,
       _notificationService = notificationService,
       _storage = storage,
       _homeService = homeService;

  static final DoseReminderCoordinator instance = DoseReminderCoordinator._(
    alarmService: MedicationAlarmService.instance,
    notificationService: LocalNotificationService.instance,
    storage: DoseReminderStorage(),
    homeService: HomeService(),
  );

  /// Instancia aislada para tests: no comparte estado con [instance].
  @visibleForTesting
  factory DoseReminderCoordinator.test({
    required MedicationAlarmService alarmService,
    required LocalNotificationService notificationService,
    required DoseReminderStorage storage,
    required HomeService homeService,
  }) {
    return DoseReminderCoordinator._(
      alarmService: alarmService,
      notificationService: notificationService,
      storage: storage,
      homeService: homeService,
    );
  }

  final MedicationAlarmService _alarmService;
  final LocalNotificationService _notificationService;
  final DoseReminderStorage _storage;
  final HomeService _homeService;

  final Map<String, Timer> _closeTimers = {};

  bool _initialized = false;

  /// Última dosis cuyo cierre (T+10) se confirmó contra el backend (ya no
  /// aparece en `next-dose`) sin que hubiera ninguna acción del paciente —
  /// Home la muestra una vez como "no tomada".
  MissedDoseSnapshot? _lastMissedDose;
  MissedDoseSnapshot? get lastMissedDose => _lastMissedDose;

  void clearLastMissedDose() {
    _lastMissedDose = null;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _reconcileAll();
  }

  @override
  void dispose() {
    for (final timer in _closeTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Future<void> _reconcileAll() async {
    final cycles = await _storage.loadCycles();
    final now = DateTime.now().toUtc();

    for (final cycle in cycles) {
      if (cycle.closed) continue;

      if (cycle.isDue(now)) {
        await _closeCycle(cycle);
      } else {
        _scheduleCloseTimer(cycle);
      }
    }
  }

  /// Punto de entrada principal: se llama cada vez que Home carga/recarga
  /// `next-dose`. Es idempotente — si ya existe un ciclo programado para la
  /// misma ocurrencia, no reprograma nada; si `next-dose` avanzó a otra
  /// ocurrencia o ya no hay dosis pendiente, cancela cualquier ciclo obsoleto.
  Future<void> ensureCycleForNextDose({
    required int patientId,
    required NextDoseModel? nextDose,
  }) async {
    await initialize();

    final cycles = await _storage.loadCycles();
    final currentKey = nextDose == null
        ? null
        : _occurrenceKey(nextDose.doseScheduleId, nextDose.scheduledAtUtc);

    // Cancela cualquier ciclo activo que ya no corresponda a la ocurrencia
    // actual de next-dose (la anterior quedó resuelta: tomada, aprobada,
    // enviada a validación, o ya no es la "next dose" vigente).
    for (final stale in cycles.where(
      (c) => !c.closed && c.occurrenceKey != currentKey,
    )) {
      await _cancelCycleReminders(stale);
      await _storage.upsertCycle(stale.copyWith(closed: true));
    }

    if (nextDose == null) return;

    // Ya hay un intento de evidencia (pendingValidation/rejected) para esta
    // dosis: no se debe seguir avisando (regla: "pendingvalidation, approved
    // y taken cancelan el ciclo"; rejected mantiene su propio flujo de
    // reintento dentro de la ventana, ajeno a este ciclo de alarmas).
    if (nextDose.complianceId != null) {
      final existing = cycles.firstWhere2(currentKey);
      if (existing != null && !existing.closed) {
        await _cancelCycleReminders(existing);
        await _storage.upsertCycle(existing.copyWith(closed: true));
      }
      return;
    }

    final existing = cycles.firstWhere2(currentKey);
    final now = DateTime.now().toUtc();

    if (existing != null) {
      if (!existing.closed && existing.isDue(now)) {
        await _closeCycle(existing);
      }
      return;
    }

    final tentativeCloseAt = nextDose.scheduledAtUtc.add(
      const Duration(minutes: AppConstants.doseReminderCloseOffsetMinutes),
    );

    if (!tentativeCloseAt.isAfter(now)) {
      // La ventana completa del ciclo ya pasó antes de que llegáramos a
      // programar nada (la app se abrió tarde): se reconcilia directamente
      // contra el backend, sin sonar alarmas para un horario ya pasado.
      final overdueCycle = DoseReminderCycle(
        patientId: patientId,
        doseScheduleId: nextDose.doseScheduleId,
        scheduledAtUtc: nextDose.scheduledAtUtc,
        medicationName: nextDose.medicationName,
        dose: nextDose.dose,
        alarmIds: const [],
        notificationIds: const [],
      );
      await _closeCycle(overdueCycle);
      return;
    }

    await _scheduleNewCycle(patientId: patientId, nextDose: nextDose);
  }

  /// Se llama cuando se envía evidencia (video) exitosamente para una dosis:
  /// cancela cualquier aviso restante — ya no debe volver a sonar ni a
  /// mostrar la acción "Tomar dosis".
  Future<void> cancelCycleForResolvedDose({
    required int doseScheduleId,
    required DateTime scheduledAtUtc,
  }) async {
    final key = _occurrenceKey(doseScheduleId, scheduledAtUtc);
    final cycles = await _storage.loadCycles();
    final cycle = cycles.firstWhere2(key);
    if (cycle == null || cycle.closed) return;

    await _cancelCycleReminders(cycle);
    await _storage.upsertCycle(cycle.copyWith(closed: true));
  }

  Future<void> _scheduleNewCycle({
    required int patientId,
    required NextDoseModel nextDose,
  }) async {
    final alarmIds = DoseReminderIdCodec.buildCycle(
      doseScheduleId: nextDose.doseScheduleId,
      scheduledAtUtc: nextDose.scheduledAtUtc,
    );
    final notificationIds = DoseReminderIdCodec.buildCycle(
      doseScheduleId: nextDose.doseScheduleId,
      scheduledAtUtc: nextDose.scheduledAtUtc,
      kind: DoseReminderIdCodec.kindNotification,
    );

    final cycle = DoseReminderCycle(
      patientId: patientId,
      doseScheduleId: nextDose.doseScheduleId,
      scheduledAtUtc: nextDose.scheduledAtUtc,
      medicationName: nextDose.medicationName,
      dose: nextDose.dose,
      alarmIds: alarmIds,
      notificationIds: notificationIds,
    );

    final attemptTitles = [
      '¡Hora de tu dosis!',
      'Aún no tomas tu dosis',
      'Último aviso: tu dosis sigue pendiente',
    ];
    final attemptTimesUtc = [
      cycle.scheduledAtUtc,
      cycle.secondAlarmAtUtc,
      cycle.thirdAlarmAtUtc,
    ];

    for (var attempt = 0; attempt < 3; attempt++) {
      final title = attemptTitles[attempt];
      final whenUtc = attemptTimesUtc[attempt];

      await _alarmService.scheduleAlarmAt(
        alarmId: alarmIds[attempt],
        dateTime: whenUtc.toLocal(),
        title: title,
        body: '${nextDose.medicationName} - ${nextDose.dose}',
      );

      await _notificationService.scheduleDoseReminderNotification(
        notificationId: notificationIds[attempt],
        title: title,
        medicationName: nextDose.medicationName,
        dose: nextDose.dose,
        dateTime: whenUtc.toLocal(),
        doseScheduleId: nextDose.doseScheduleId,
        scheduledAtUtc: nextDose.scheduledAtUtc,
        alarmId: alarmIds[attempt],
      );
    }

    await _storage.upsertCycle(cycle);
    _scheduleCloseTimer(cycle);
  }

  void _scheduleCloseTimer(DoseReminderCycle cycle) {
    _closeTimers.remove(cycle.occurrenceKey)?.cancel();

    final delay = cycle.closeAtUtc.difference(DateTime.now().toUtc());
    if (!delay.isNegative) {
      _closeTimers[cycle.occurrenceKey] = Timer(
        delay,
        () => _closeDueCycle(cycle.occurrenceKey),
      );
    }
  }

  Future<void> _closeDueCycle(String occurrenceKey) async {
    final cycles = await _storage.loadCycles();
    final cycle = cycles.firstWhere2(occurrenceKey);
    if (cycle == null || cycle.closed) return;
    await _closeCycle(cycle);
  }

  /// Llegado T+10: detiene cualquier alarma/notificación que quedara viva
  /// (limpieza, sin significado de negocio) y reconcilia contra el backend.
  /// El registro definitivo como `skipped` lo hace `StaleDoseExpirationService`
  /// en FollowUp-Service — este método NUNCA llama a ese endpoint, solo
  /// refleja localmente lo que el backend ya confirmó, para no arriesgar una
  /// doble escritura sin índice único.
  Future<void> _closeCycle(DoseReminderCycle cycle) async {
    await _cancelCycleReminders(cycle);

    NextDoseModel? fresh;
    try {
      fresh = await _homeService.getNextDose(cycle.patientId);
    } catch (_) {
      // Sin conexión: no se puede confirmar. No se marca `closed` — se
      // reintentará en la próxima reconciliación.
      return;
    }

    final sameOccurrenceStillPending =
        fresh != null &&
        fresh.doseScheduleId == cycle.doseScheduleId &&
        fresh.scheduledAtUtc.isAtSameMomentAs(cycle.scheduledAtUtc);

    if (sameOccurrenceStillPending) {
      // El worker de FollowUp-Service todavía no la cerró (corre cada
      // minuto) o el reloj del dispositivo va adelantado: no se marca
      // `closed` para poder reconciliar de nuevo más adelante, y no se
      // asume "no tomada" hasta que el backend lo confirme.
      return;
    }

    // El backend ya no la reporta como pendiente: quedó resuelta (lo más
    // probable, cerrada como `skipped` por el worker, o tomada/validada por
    // otra vía). Se refleja localmente para que Home muestre "no tomada"
    // hasta el próximo refresco real.
    _lastMissedDose = MissedDoseSnapshot(
      doseScheduleId: cycle.doseScheduleId,
      scheduledAtUtc: cycle.scheduledAtUtc,
      medicationName: cycle.medicationName,
      dose: cycle.dose,
    );
    await _storage.upsertCycle(cycle.copyWith(closed: true));
    notifyListeners();
  }

  Future<void> _cancelCycleReminders(DoseReminderCycle cycle) async {
    _closeTimers.remove(cycle.occurrenceKey)?.cancel();
    for (final id in cycle.alarmIds) {
      await _alarmService.stopAlarm(id);
    }
    for (final id in cycle.notificationIds) {
      await _notificationService.cancelNotification(id);
    }
  }

  String _occurrenceKey(int doseScheduleId, DateTime scheduledAtUtc) =>
      '$doseScheduleId@${scheduledAtUtc.toIso8601String()}';
}

extension _FirstWhereOrNullCycle on List<DoseReminderCycle> {
  DoseReminderCycle? firstWhere2(String? key) {
    if (key == null) return null;
    for (final cycle in this) {
      if (cycle.occurrenceKey == key) return cycle;
    }
    return null;
  }
}
