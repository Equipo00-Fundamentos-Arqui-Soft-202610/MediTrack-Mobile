import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meditrack_mobile/core/alarms/medication_alarm_service.dart';
import 'package:meditrack_mobile/core/notifications/local_notification_service.dart';
import 'package:meditrack_mobile/core/session/session_controller.dart';
import 'package:meditrack_mobile/features/auth/domain/models/user_session.dart';
import 'package:meditrack_mobile/features/home/data/models/next_dose_model.dart';
import 'package:meditrack_mobile/features/home/data/services/home_service.dart';
import 'package:meditrack_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:meditrack_mobile/features/reminders/application/services/dose_reminder_coordinator.dart';
import 'package:meditrack_mobile/features/reminders/data/dose_reminder_storage.dart';
import 'package:meditrack_mobile/features/reminders/data/pending_dose_action_store.dart';

/// Fake sin red: cuenta cuántas veces se llamó getNextDose, para verificar
/// que "resume" desde background dispara una recarga real.
class _FakeHomeService implements HomeService {
  _FakeHomeService({NextDoseModel? fixedDose}) : _fixedDose = fixedDose;

  final NextDoseModel? _fixedDose;
  int getNextDoseCallCount = 0;

  @override
  Future<NextDoseModel?> getNextDose(int patientId) async {
    getNextDoseCallCount++;
    return _fixedDose ??
        NextDoseModel(
          doseScheduleId: 1,
          medicationName: 'Losartán',
          dose: '50mg',
          scheduledTime: '08:00',
          minutesUntilDose: 0,
          scheduledAtUtc: DateTime.now().toUtc().add(const Duration(hours: 2)),
          complianceId: null,
          validationStatus: null,
          rejectionReason: null,
        );
  }

  @override
  Future<double> getAdherencePercentage(int patientId) async => 80;

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

/// Fake sin plataforma real: el paquete `alarm` usa MethodChannels que no
/// existen en `flutter test`, así que se stubean todos sus métodos.
class _FakeAlarmService implements MedicationAlarmService {
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

  @override
  Future<void> stopAlarm(int alarmId) async {}

  @override
  Future<void> scheduleAlarmAt({
    required int alarmId,
    required DateTime dateTime,
    required String title,
    required String body,
  }) async {}
}

/// Fake sin plataforma real para `flutter_local_notifications`.
class _FakeNotificationService implements LocalNotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> requestPermissions() async {}

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
  }) async {}

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
  Future<void> cancelNotification(int notificationId) async {}

  @override
  Future<void> cancelAllNotifications() async {}

  @override
  Future<NotificationAppLaunchDetails?> getLaunchDetails() async => null;

  @override
  Future<void> handleColdStartLaunch() async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Home recarga next-dose automáticamente al reanudar desde background',
    (tester) async {
      final sessionController = SessionController();
      sessionController.debugSetSession(
        const UserSession(
          token: 'fake-token',
          id: 1,
          nombre: 'Paciente Demo',
          email: 'demo@meditrack.test',
          rol: 'paciente',
          institucion: null,
          phoneNumber: null,
          profilePhotoUrl: null,
          patientId: 1,
        ),
      );

      final fakeHomeService = _FakeHomeService();
      final reminderCoordinator = DoseReminderCoordinator.test(
        alarmService: _FakeAlarmService(),
        notificationService: _FakeNotificationService(),
        storage: DoseReminderStorage(),
        homeService: fakeHomeService,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<SessionController>.value(
          value: sessionController,
          child: MaterialApp(
            home: HomeScreen(
              homeService: fakeHomeService,
              reminderCoordinator: reminderCoordinator,
            ),
          ),
        ),
      );

      // Deja que las llamadas del fake (instantáneas) resuelvan sin esperar
      // pumpAndSettle (evita depender de que absolutamente todo termine).
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(fakeHomeService.getNextDoseCallCount, 1);

      // Simula la app yendo a background y volviendo (resume).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(fakeHomeService.getNextDoseCallCount, 2);

      // El coordinador programa un Timer real para el cierre del ciclo; hay
      // que liberarlo explícitamente antes de que termine el test, o
      // `flutter_test` falla por un timer pendiente tras desechar los widgets.
      reminderCoordinator.dispose();
    },
  );

  testWidgets(
    'Home abre automáticamente la evidencia de la dosis correcta cuando hay una solicitud "Tomar dosis" pendiente que coincide',
    (tester) async {
      final sessionController = SessionController();
      sessionController.debugSetSession(
        const UserSession(
          token: 'fake-token',
          id: 1,
          nombre: 'Paciente Demo',
          email: 'demo@meditrack.test',
          rol: 'paciente',
          institucion: null,
          phoneNumber: null,
          profilePhotoUrl: null,
          patientId: 1,
        ),
      );

      final scheduledAtUtc = DateTime.utc(2026, 7, 11, 13, 0, 0);
      final fixedDose = NextDoseModel(
        doseScheduleId: 1,
        medicationName: 'Losartán',
        dose: '50mg',
        scheduledTime: '08:00',
        minutesUntilDose: 0,
        scheduledAtUtc: scheduledAtUtc,
        complianceId: null,
        validationStatus: null,
        rejectionReason: null,
      );
      final fakeHomeService = _FakeHomeService(fixedDose: fixedDose);
      final reminderCoordinator = DoseReminderCoordinator.test(
        alarmService: _FakeAlarmService(),
        notificationService: _FakeNotificationService(),
        storage: DoseReminderStorage(),
        homeService: fakeHomeService,
      );

      // Simula que ya se tocó "Tomar dosis" en la notificación (foreground,
      // background o app terminada) para esta dosis exacta, antes de que
      // Home llegara a cargar.
      await PendingDoseActionStore.persist(
        doseScheduleId: 1,
        scheduledAtUtc: scheduledAtUtc,
      );

      NextDoseModel? openedDose;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => HomeScreen(
              homeService: fakeHomeService,
              reminderCoordinator: reminderCoordinator,
            ),
          ),
          GoRoute(
            path: '/dose-evidence',
            builder: (context, state) {
              openedDose = state.extra as NextDoseModel;
              return const SizedBox.shrink();
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<SessionController>.value(
          value: sessionController,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(openedDose, isNotNull);
      expect(openedDose!.doseScheduleId, 1);
      expect(openedDose!.scheduledAtUtc, scheduledAtUtc);

      reminderCoordinator.dispose();
    },
  );
}
