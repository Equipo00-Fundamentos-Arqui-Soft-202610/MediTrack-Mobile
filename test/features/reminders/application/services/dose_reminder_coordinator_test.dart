import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meditrack_mobile/core/alarms/medication_alarm_service.dart';
import 'package:meditrack_mobile/core/notifications/local_notification_service.dart';
import 'package:meditrack_mobile/features/home/data/models/next_dose_model.dart';
import 'package:meditrack_mobile/features/home/data/services/home_service.dart';
import 'package:meditrack_mobile/features/reminders/application/services/dose_reminder_coordinator.dart';
import 'package:meditrack_mobile/features/reminders/data/dose_reminder_storage.dart';
import 'package:meditrack_mobile/features/reminders/domain/dose_reminder_id_codec.dart';
import 'package:meditrack_mobile/features/reminders/domain/models/dose_reminder_cycle.dart';

class _ScheduledAlarm {
  final int id;
  final DateTime dateTime;
  _ScheduledAlarm(this.id, this.dateTime);
}

class _ScheduledNotification {
  final int id;
  final int doseScheduleId;
  final int alarmId;
  _ScheduledNotification(this.id, this.doseScheduleId, this.alarmId);
}

/// Fake sin plataforma real. A propósito NO expone ningún stream de
/// "ringing": el coordinador rediseñado no escucha el estado de la alarma
/// para nada, así que ni siquiera hace falta simularlo.
class _FakeAlarmService implements MedicationAlarmService {
  final List<_ScheduledAlarm> scheduledCalls = [];
  final List<int> stoppedIds = [];

  @override
  Future<void> scheduleAlarmAt({
    required int alarmId,
    required DateTime dateTime,
    required String title,
    required String body,
  }) async {
    scheduledCalls.add(_ScheduledAlarm(alarmId, dateTime));
  }

  @override
  Future<void> stopAlarm(int alarmId) async {
    stoppedIds.add(alarmId);
  }

  @override
  Future<void> scheduleMedicationAlarm({
    required int alarmId,
    required String medicationName,
    required String dose,
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<void> scheduleTestMedicationAlarm() async {}
}

class _FakeNotificationService implements LocalNotificationService {
  final List<_ScheduledNotification> scheduledCalls = [];
  final List<int> cancelledIds = [];

  @override
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
    scheduledCalls.add(
      _ScheduledNotification(notificationId, doseScheduleId, alarmId),
    );
  }

  @override
  Future<void> cancelNotification(int notificationId) async {
    cancelledIds.add(notificationId);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> scheduleDailyMedicationNotification({
    required int notificationId,
    required String medicationName,
    required String dose,
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    int notificationId = 0,
  }) async {}

  @override
  Future<void> showTestMedicationNotification() async {}

  @override
  Future<void> cancelAllNotifications() async {}

  @override
  Future<NotificationAppLaunchDetails?> getLaunchDetails() async => null;

  @override
  Future<void> handleColdStartLaunch() async {}
}

class _FakeHomeService implements HomeService {
  NextDoseModel? Function(int patientId)? onGetNextDose;

  @override
  Future<NextDoseModel?> getNextDose(int patientId) async =>
      onGetNextDose?.call(patientId);

  @override
  Future<double> getAdherencePercentage(int patientId) async => 0;

  @override
  Future<List<dynamic>> getLowStockMedications(int patientId) async => [];

  @override
  Future<void> takeDose({
    required int patientId,
    required int doseScheduleId,
  }) async {}

  @override
  Future<int> uploadComplianceVideo({
    required int doseScheduleId,
    required File videoFile,
    void Function(int sent, int total)? onSendProgress,
  }) async => 1;

  @override
  Future<Map<String, dynamic>> getComplianceStatus(int complianceId) async =>
      {};
}

NextDoseModel _dose({
  required int doseScheduleId,
  required DateTime scheduledAtUtc,
  int? complianceId,
}) {
  return NextDoseModel(
    doseScheduleId: doseScheduleId,
    medicationName: 'Losartán',
    dose: '50mg',
    scheduledTime: '08:00',
    minutesUntilDose: 0,
    scheduledAtUtc: scheduledAtUtc,
    complianceId: complianceId,
    validationStatus: complianceId == null ? null : 'PendingValidation',
    rejectionReason: null,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DoseReminderCoordinator.ensureCycleForNextDose — programación', () {
    test(
      'programa exactamente 3 alarmas y 3 notificaciones "Tomar dosis" con IDs determinísticos',
      () async {
        final alarmService = _FakeAlarmService();
        final notificationService = _FakeNotificationService();
        final homeService = _FakeHomeService();
        final coordinator = DoseReminderCoordinator.test(
          alarmService: alarmService,
          notificationService: notificationService,
          storage: DoseReminderStorage(),
          homeService: homeService,
        );

        final scheduledAtUtc = DateTime.now().toUtc().add(
          const Duration(minutes: 2),
        );
        final dose = _dose(doseScheduleId: 200, scheduledAtUtc: scheduledAtUtc);

        await coordinator.ensureCycleForNextDose(patientId: 1, nextDose: dose);

        expect(alarmService.scheduledCalls.length, 3);
        expect(notificationService.scheduledCalls.length, 3);

        final expectedAlarmIds = DoseReminderIdCodec.buildCycle(
          doseScheduleId: 200,
          scheduledAtUtc: scheduledAtUtc,
        );
        final expectedNotificationIds = DoseReminderIdCodec.buildCycle(
          doseScheduleId: 200,
          scheduledAtUtc: scheduledAtUtc,
          kind: DoseReminderIdCodec.kindNotification,
        );
        expect(
          alarmService.scheduledCalls.map((c) => c.id).toSet(),
          expectedAlarmIds.toSet(),
        );
        expect(
          notificationService.scheduledCalls.map((c) => c.id).toSet(),
          expectedNotificationIds.toSet(),
        );

        // Cada notificación debe llevar el alarmId de SU MISMO intento (para
        // poder detener únicamente esa alarma puntual al tocar "Tomar dosis").
        for (final n in notificationService.scheduledCalls) {
          expect(expectedAlarmIds.contains(n.alarmId), isTrue);
          expect(n.doseScheduleId, 200);
        }
      },
    );

    test(
      'no duplica alarmas ni notificaciones si Home recarga con la misma ocurrencia',
      () async {
        final alarmService = _FakeAlarmService();
        final notificationService = _FakeNotificationService();
        final coordinator = DoseReminderCoordinator.test(
          alarmService: alarmService,
          notificationService: notificationService,
          storage: DoseReminderStorage(),
          homeService: _FakeHomeService(),
        );

        final scheduledAtUtc = DateTime.now().toUtc().add(
          const Duration(minutes: 2),
        );
        final dose = _dose(doseScheduleId: 200, scheduledAtUtc: scheduledAtUtc);

        await coordinator.ensureCycleForNextDose(patientId: 1, nextDose: dose);
        await coordinator.ensureCycleForNextDose(patientId: 1, nextDose: dose);
        await coordinator.ensureCycleForNextDose(patientId: 1, nextDose: dose);

        expect(alarmService.scheduledCalls.length, 3);
        expect(notificationService.scheduledCalls.length, 3);
      },
    );

    test('el timeline generado es exactamente T+0, T+4, T+7 y T+10', () async {
      final alarmService = _FakeAlarmService();
      final notificationService = _FakeNotificationService();
      final coordinator = DoseReminderCoordinator.test(
        alarmService: alarmService,
        notificationService: notificationService,
        storage: DoseReminderStorage(),
        homeService: _FakeHomeService(),
      );

      final scheduledAtUtc = DateTime.now().toUtc().add(
        const Duration(minutes: 2),
      );
      final dose = _dose(doseScheduleId: 200, scheduledAtUtc: scheduledAtUtc);
      await coordinator.ensureCycleForNextDose(patientId: 1, nextDose: dose);

      final times =
          alarmService.scheduledCalls.map((c) => c.dateTime.toUtc()).toList()
            ..sort();
      expect(times[0].difference(scheduledAtUtc), Duration.zero);
      expect(times[1].difference(scheduledAtUtc), const Duration(minutes: 4));
      expect(times[2].difference(scheduledAtUtc), const Duration(minutes: 7));

      final cycles = await DoseReminderStorage().loadCycles();
      expect(
        cycles.single.closeAtUtc.difference(scheduledAtUtc),
        const Duration(minutes: 10),
      );
    });

    test(
      'con complianceId (PendingValidation/Approved/Taken vía next-dose) cancela el ciclo',
      () async {
        final alarmService = _FakeAlarmService();
        final notificationService = _FakeNotificationService();
        final coordinator = DoseReminderCoordinator.test(
          alarmService: alarmService,
          notificationService: notificationService,
          storage: DoseReminderStorage(),
          homeService: _FakeHomeService(),
        );

        final scheduledAtUtc = DateTime.now().toUtc().add(
          const Duration(minutes: 2),
        );
        final dose = _dose(
          doseScheduleId: 200,
          scheduledAtUtc: scheduledAtUtc,
          complianceId: 42,
        );

        await coordinator.ensureCycleForNextDose(patientId: 1, nextDose: dose);

        expect(alarmService.scheduledCalls, isEmpty);
        expect(notificationService.scheduledCalls, isEmpty);
      },
    );

    test(
      'nextDose null (dosis Taken/Approved/Skipped, ya excluida de next-dose) cancela cualquier ciclo activo previo',
      () async {
        final alarmService = _FakeAlarmService();
        final notificationService = _FakeNotificationService();
        final coordinator = DoseReminderCoordinator.test(
          alarmService: alarmService,
          notificationService: notificationService,
          storage: DoseReminderStorage(),
          homeService: _FakeHomeService(),
        );

        final scheduledAtUtc = DateTime.now().toUtc().add(
          const Duration(minutes: 2),
        );
        final dose = _dose(doseScheduleId: 200, scheduledAtUtc: scheduledAtUtc);
        await coordinator.ensureCycleForNextDose(patientId: 1, nextDose: dose);

        await coordinator.ensureCycleForNextDose(patientId: 1, nextDose: null);

        final expectedAlarmIds = DoseReminderIdCodec.buildCycle(
          doseScheduleId: 200,
          scheduledAtUtc: scheduledAtUtc,
        );
        final expectedNotificationIds = DoseReminderIdCodec.buildCycle(
          doseScheduleId: 200,
          scheduledAtUtc: scheduledAtUtc,
          kind: DoseReminderIdCodec.kindNotification,
        );
        expect(alarmService.stoppedIds.toSet(), expectedAlarmIds.toSet());
        expect(
          notificationService.cancelledIds.toSet(),
          expectedNotificationIds.toSet(),
        );
      },
    );
  });

  group(
    'DoseReminderCoordinator — silenciar una alarma no tiene efecto de negocio',
    () {
      test(
        'detener una alarma directamente (fuera del coordinador) no cancela los avisos 2 y 3 ni cierra el ciclo',
        () async {
          final alarmService = _FakeAlarmService();
          final notificationService = _FakeNotificationService();
          final storage = DoseReminderStorage();
          final coordinator = DoseReminderCoordinator.test(
            alarmService: alarmService,
            notificationService: notificationService,
            storage: storage,
            homeService: _FakeHomeService(),
          );

          final scheduledAtUtc = DateTime.now().toUtc().add(
            const Duration(minutes: 2),
          );
          final dose = _dose(
            doseScheduleId: 200,
            scheduledAtUtc: scheduledAtUtc,
          );
          await coordinator.ensureCycleForNextDose(
            patientId: 1,
            nextDose: dose,
          );

          final ids = DoseReminderIdCodec.buildCycle(
            doseScheduleId: 200,
            scheduledAtUtc: scheduledAtUtc,
          );

          // Simula que el paciente detuvo/deslizó/silenció la alarma inicial —
          // el coordinador no escucha ningún stream de "ringing", así que esto
          // no puede tener ningún efecto sobre el ciclo persistido.
          await alarmService.stopAlarm(ids[0]);

          final cycles = await storage.loadCycles();
          expect(cycles.single.closed, isFalse);
          expect(cycles.single.alarmIds, ids);
          // El coordinador mismo nunca detuvo ni canceló los avisos 2 y 3.
          expect(alarmService.stoppedIds, [ids[0]]);
          expect(notificationService.cancelledIds, isEmpty);
        },
      );
    },
  );

  group('DoseReminderCoordinator.cancelCycleForResolvedDose', () {
    test(
      'cancela las alarmas Y notificaciones restantes al enviar evidencia',
      () async {
        final alarmService = _FakeAlarmService();
        final notificationService = _FakeNotificationService();
        final coordinator = DoseReminderCoordinator.test(
          alarmService: alarmService,
          notificationService: notificationService,
          storage: DoseReminderStorage(),
          homeService: _FakeHomeService(),
        );

        final scheduledAtUtc = DateTime.now().toUtc().add(
          const Duration(minutes: 2),
        );
        final dose = _dose(doseScheduleId: 200, scheduledAtUtc: scheduledAtUtc);
        await coordinator.ensureCycleForNextDose(patientId: 1, nextDose: dose);

        await coordinator.cancelCycleForResolvedDose(
          doseScheduleId: 200,
          scheduledAtUtc: scheduledAtUtc,
        );

        final expectedAlarmIds = DoseReminderIdCodec.buildCycle(
          doseScheduleId: 200,
          scheduledAtUtc: scheduledAtUtc,
        );
        final expectedNotificationIds = DoseReminderIdCodec.buildCycle(
          doseScheduleId: 200,
          scheduledAtUtc: scheduledAtUtc,
          kind: DoseReminderIdCodec.kindNotification,
        );
        expect(alarmService.stoppedIds.toSet(), expectedAlarmIds.toSet());
        expect(
          notificationService.cancelledIds.toSet(),
          expectedNotificationIds.toSet(),
        );
      },
    );
  });

  group(
    'DoseReminderCoordinator — cierre a T+10 (sin registrar skipped desde el mobile)',
    () {
      test(
        'si el backend ya no reporta la ocurrencia, la refleja como "no tomada" localmente sin llamar a ningún endpoint de skip',
        () async {
          final alarmService = _FakeAlarmService();
          final notificationService = _FakeNotificationService();
          final homeService = _FakeHomeService();
          final scheduledAtUtc = DateTime.now().toUtc().subtract(
            const Duration(minutes: 11),
          );
          final dose = _dose(
            doseScheduleId: 300,
            scheduledAtUtc: scheduledAtUtc,
          );
          // El backend (worker StaleDoseExpirationService) ya cerró esta dosis:
          // next-dose ya no la reporta.
          homeService.onGetNextDose = (_) => null;

          final coordinator = DoseReminderCoordinator.test(
            alarmService: alarmService,
            notificationService: notificationService,
            storage: DoseReminderStorage(),
            homeService: homeService,
          );

          // La app se "abre tarde": scheduledAtUtc ya pasó por más de T+10.
          await coordinator.ensureCycleForNextDose(
            patientId: 1,
            nextDose: dose,
          );

          expect(coordinator.lastMissedDose?.doseScheduleId, 300);

          final cycles = await DoseReminderStorage().loadCycles();
          expect(cycles.single.closed, isTrue);
        },
      );

      test(
        'si el backend TODAVÍA reporta la misma ocurrencia (worker no la cerró aún), no marca "no tomada" y reintentará después',
        () async {
          final alarmService = _FakeAlarmService();
          final notificationService = _FakeNotificationService();
          final homeService = _FakeHomeService();
          final scheduledAtUtc = DateTime.now().toUtc().subtract(
            const Duration(minutes: 11),
          );
          final dose = _dose(
            doseScheduleId: 301,
            scheduledAtUtc: scheduledAtUtc,
          );
          // El worker corre cada minuto: todavía puede no haber pasado por esta
          // ocurrencia. next-dose la sigue devolviendo tal cual.
          homeService.onGetNextDose = (_) => dose;

          final coordinator = DoseReminderCoordinator.test(
            alarmService: alarmService,
            notificationService: notificationService,
            storage: DoseReminderStorage(),
            homeService: homeService,
          );

          await coordinator.ensureCycleForNextDose(
            patientId: 1,
            nextDose: dose,
          );

          // Como esta ocurrencia nunca llegó a programarse (la app se abrió ya
          // vencida) y el backend todavía la confirma pendiente, no hay nada que
          // persistir todavía: ni se marca "no tomada" ni se cierra un ciclo que
          // nunca existió — se reintentará en la próxima carga de Home.
          expect(coordinator.lastMissedDose, isNull);
          final cycles = await DoseReminderStorage().loadCycles();
          expect(cycles, isEmpty);
        },
      );
    },
  );

  group('DoseReminderCoordinator — restauración tras reinicio', () {
    test(
      'un ciclo persistido y vencido se reconcilia (y refleja como no tomada) al reiniciar el coordinador',
      () async {
        final homeService = _FakeHomeService();
        final storage = DoseReminderStorage();
        final scheduledAtUtc = DateTime.now().toUtc().subtract(
          const Duration(minutes: 11),
        );
        homeService.onGetNextDose = (_) => null; // el worker ya la cerró

        final alarmIds = DoseReminderIdCodec.buildCycle(
          doseScheduleId: 400,
          scheduledAtUtc: scheduledAtUtc,
        );
        final notificationIds = DoseReminderIdCodec.buildCycle(
          doseScheduleId: 400,
          scheduledAtUtc: scheduledAtUtc,
          kind: DoseReminderIdCodec.kindNotification,
        );
        // Simula una ejecución previa que programó el ciclo (persistido) pero
        // cuyo proceso murió antes de llegar a reconciliarlo.
        await storage.upsertCycle(
          DoseReminderCycle(
            patientId: 1,
            doseScheduleId: 400,
            scheduledAtUtc: scheduledAtUtc,
            medicationName: 'Losartán',
            dose: '50mg',
            alarmIds: alarmIds,
            notificationIds: notificationIds,
          ),
        );

        // "Reinicio de la app": nueva instancia del coordinador, misma storage.
        final coordinatorB = DoseReminderCoordinator.test(
          alarmService: _FakeAlarmService(),
          notificationService: _FakeNotificationService(),
          storage: storage,
          homeService: homeService,
        );

        await coordinatorB.initialize();

        expect(coordinatorB.lastMissedDose?.doseScheduleId, 400);
      },
    );
  });
}
