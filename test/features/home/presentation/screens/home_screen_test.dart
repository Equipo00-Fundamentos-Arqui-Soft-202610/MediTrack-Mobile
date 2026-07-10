import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:meditrack_mobile/core/session/session_controller.dart';
import 'package:meditrack_mobile/features/auth/domain/models/user_session.dart';
import 'package:meditrack_mobile/features/home/data/models/next_dose_model.dart';
import 'package:meditrack_mobile/features/home/data/services/home_service.dart';
import 'package:meditrack_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:meditrack_mobile/features/medications/data/services/medication_service.dart';
import 'package:meditrack_mobile/features/medications/domain/models/medication_model.dart';

/// Fake sin red: cuenta cuántas veces se llamó getNextDose, para verificar
/// que "resume" desde background dispara una recarga real.
class _FakeHomeService implements HomeService {
  int getNextDoseCallCount = 0;

  @override
  Future<NextDoseModel?> getNextDose(int patientId) async {
    getNextDoseCallCount++;
    return NextDoseModel(
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
  Future<void> takeDose({required int patientId, required int doseScheduleId}) async {}

  @override
  Future<int> uploadComplianceVideo({
    required int doseScheduleId,
    required File videoFile,
    void Function(int sent, int total)? onSendProgress,
  }) async => 1;

  @override
  Future<Map<String, dynamic>> getComplianceStatus(int complianceId) async => {};
}

class _FakeMedicationService implements MedicationService {
  @override
  Future<List<MedicationModel>> getMedicationsByPatientId(int patientId) async => [];
}

void main() {
  testWidgets('Home recarga next-dose automáticamente al reanudar desde background', (tester) async {
    final sessionController = SessionController();
    sessionController.debugSetSession(const UserSession(
      token: 'fake-token',
      id: 1,
      nombre: 'Paciente Demo',
      email: 'demo@meditrack.test',
      rol: 'paciente',
      institucion: null,
      phoneNumber: null,
      profilePhotoUrl: null,
      patientId: 1,
    ));

    final fakeHomeService = _FakeHomeService();

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionController>.value(
        value: sessionController,
        child: MaterialApp(
          home: HomeScreen(
            homeService: fakeHomeService,
            medicationService: _FakeMedicationService(),
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
  });
}
