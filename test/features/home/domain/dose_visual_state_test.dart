import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack_mobile/features/home/data/models/next_dose_model.dart';
import 'package:meditrack_mobile/features/home/domain/dose_visual_state.dart';

NextDoseModel _dose({
  required DateTime scheduledAtUtc,
  String? validationStatus,
  String? rejectionReason,
}) {
  return NextDoseModel(
    doseScheduleId: 1,
    medicationName: 'Losartán',
    dose: '50mg',
    scheduledTime: '08:00',
    minutesUntilDose: 0,
    scheduledAtUtc: scheduledAtUtc,
    complianceId: validationStatus == null ? null : 42,
    validationStatus: validationStatus,
    rejectionReason: rejectionReason,
  );
}

void main() {
  group('computeDoseState', () {
    test('sin dosis -> beforeWindow', () {
      final result = computeDoseState(null, DateTime.now().toUtc());
      expect(result.state, DoseVisualState.beforeWindow);
    });

    test('antes del horario programado -> beforeWindow', () {
      final now = DateTime.now().toUtc();
      final dose = _dose(scheduledAtUtc: now.add(const Duration(minutes: 30)));
      expect(computeDoseState(dose, now).state, DoseVisualState.beforeWindow);
    });

    test('dosis 5 minutos en el futuro -> beforeWindow, botón deshabilitado', () {
      final now = DateTime.now().toUtc();
      final dose = _dose(scheduledAtUtc: now.add(const Duration(minutes: 5)));
      final result = computeDoseState(dose, now);
      expect(result.state, DoseVisualState.beforeWindow);
    });

    test('justo en el horario -> readyToTake', () {
      final now = DateTime.now().toUtc();
      final dose = _dose(scheduledAtUtc: now);
      expect(computeDoseState(dose, now).state, DoseVisualState.readyToTake);
    });

    test('dentro de la tolerancia (59 min) -> readyToTake', () {
      final now = DateTime.now().toUtc();
      final dose = _dose(scheduledAtUtc: now.subtract(const Duration(minutes: 59)));
      expect(computeDoseState(dose, now).state, DoseVisualState.readyToTake);
    });

    test('pasada la tolerancia de 60 min sin intento -> windowExpired', () {
      final now = DateTime.now().toUtc();
      final dose = _dose(scheduledAtUtc: now.subtract(const Duration(minutes: 61)));
      expect(computeDoseState(dose, now).state, DoseVisualState.windowExpired);
    });

    test('PendingValidation -> pendingValidation sin importar la hora', () {
      final now = DateTime.now().toUtc();
      final dose = _dose(
        scheduledAtUtc: now.subtract(const Duration(hours: 5)),
        validationStatus: 'PendingValidation',
      );
      expect(computeDoseState(dose, now).state, DoseVisualState.pendingValidation);
    });

    test('Rejected dentro de ventana -> rejected con canRetry=true', () {
      final now = DateTime.now().toUtc();
      final dose = _dose(
        scheduledAtUtc: now.subtract(const Duration(minutes: 10)),
        validationStatus: 'Rejected',
        rejectionReason: 'Video borroso',
      );
      final result = computeDoseState(dose, now);
      expect(result.state, DoseVisualState.rejected);
      expect(result.canRetry, isTrue);
    });

    test('Rejected fuera de ventana -> rejected con canRetry=false', () {
      final now = DateTime.now().toUtc();
      final dose = _dose(
        scheduledAtUtc: now.subtract(const Duration(minutes: 90)),
        validationStatus: 'Rejected',
      );
      final result = computeDoseState(dose, now);
      expect(result.state, DoseVisualState.rejected);
      expect(result.canRetry, isFalse);
    });
  });

  group('NextDoseModel.fromJson — conversión UTC a local', () {
    test('parsea scheduledAtUtc con sufijo Z como UTC inequívoco', () {
      final json = {
        'doseScheduleId': 1,
        'medicationName': 'Losartán',
        'dose': '50mg',
        'scheduledTime': '08:00',
        'minutesUntilDose': 30,
        'scheduledAtUtc': '2026-07-10T13:00:00.0000000Z',
        'complianceId': null,
        'validationStatus': null,
        'rejectionReason': null,
      };

      final model = NextDoseModel.fromJson(json);

      expect(model.scheduledAtUtc.isUtc, isTrue);
      expect(model.scheduledAtUtc, DateTime.utc(2026, 7, 10, 13, 0, 0));

      // .toLocal() debe dar un instante equivalente (mismo punto en el
      // tiempo), sin concatenar fecha/hora manualmente ni asumir la zona del
      // dispositivo como si fuera la del backend.
      final asLocal = model.scheduledAtUtc.toLocal();
      expect(asLocal.toUtc(), model.scheduledAtUtc);
    });

    test('parsea scheduledAtUtc con offset explícito (no solo Z) correctamente', () {
      final json = {
        'doseScheduleId': 1,
        'medicationName': 'Losartán',
        'dose': '50mg',
        'scheduledTime': '08:00',
        'minutesUntilDose': 30,
        // Equivalente a las 13:00 UTC, expresado con offset -05:00 (Lima).
        'scheduledAtUtc': '2026-07-10T08:00:00-05:00',
        'complianceId': null,
        'validationStatus': null,
        'rejectionReason': null,
      };

      final model = NextDoseModel.fromJson(json);

      expect(model.scheduledAtUtc, DateTime.utc(2026, 7, 10, 13, 0, 0));
    });
  });
}
