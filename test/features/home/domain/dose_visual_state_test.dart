import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack_mobile/features/home/data/models/next_dose_model.dart';
import 'package:meditrack_mobile/features/home/domain/dose_visual_state.dart';
import 'package:meditrack_mobile/features/reminders/domain/models/missed_dose_snapshot.dart';

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

    test(
      'dosis 5 minutos en el futuro -> beforeWindow, botón deshabilitado',
      () {
        final now = DateTime.now().toUtc();
        final dose = _dose(scheduledAtUtc: now.add(const Duration(minutes: 5)));
        final result = computeDoseState(dose, now);
        expect(result.state, DoseVisualState.beforeWindow);
      },
    );

    test('justo en el horario -> readyToTake', () {
      final now = DateTime.now().toUtc();
      final dose = _dose(scheduledAtUtc: now);
      expect(computeDoseState(dose, now).state, DoseVisualState.readyToTake);
    });

    test(
      'dentro de la ventana de toma (9 min, antes de T+10) -> readyToTake',
      () {
        final now = DateTime.now().toUtc();
        final dose = _dose(
          scheduledAtUtc: now.subtract(const Duration(minutes: 9)),
        );
        expect(computeDoseState(dose, now).state, DoseVisualState.readyToTake);
      },
    );

    test('pasado T+10 sin ningún intento -> windowExpired', () {
      final now = DateTime.now().toUtc();
      final dose = _dose(
        scheduledAtUtc: now.subtract(const Duration(minutes: 11)),
      );
      expect(computeDoseState(dose, now).state, DoseVisualState.windowExpired);
    });

    test('PendingValidation -> pendingValidation sin importar la hora', () {
      final now = DateTime.now().toUtc();
      final dose = _dose(
        scheduledAtUtc: now.subtract(const Duration(hours: 5)),
        validationStatus: 'PendingValidation',
      );
      expect(
        computeDoseState(dose, now).state,
        DoseVisualState.pendingValidation,
      );
    });

    test(
      'Rejected antes de T+10 -> rejected con canRetry=true (permite reintento)',
      () {
        final now = DateTime.now().toUtc();
        final dose = _dose(
          scheduledAtUtc: now.subtract(const Duration(minutes: 5)),
          validationStatus: 'Rejected',
          rejectionReason: 'Video borroso',
        );
        final result = computeDoseState(dose, now);
        expect(result.state, DoseVisualState.rejected);
        expect(result.canRetry, isTrue);
      },
    );

    test(
      'Rejected después de T+10 -> rejected con canRetry=false (ya no permite grabar otro video)',
      () {
        final now = DateTime.now().toUtc();
        final dose = _dose(
          scheduledAtUtc: now.subtract(const Duration(minutes: 15)),
          validationStatus: 'Rejected',
        );
        final result = computeDoseState(dose, now);
        // Se mantiene "rejected" (no se convierte a notTaken/skipped): conserva
        // el historial del intento rechazado, solo se deshabilita el reintento.
        expect(result.state, DoseVisualState.rejected);
        expect(result.canRetry, isFalse);
      },
    );

    test(
      'dosis perdida localmente y next-dose ya sin esa ocurrencia -> notTaken',
      () {
        final now = DateTime.now().toUtc();
        final missedAt = now.subtract(const Duration(minutes: 20));
        final missed = MissedDoseSnapshot(
          doseScheduleId: 1,
          scheduledAtUtc: missedAt,
          medicationName: 'Losartán',
          dose: '50mg',
        );

        // El backend ya avanzó (o no hay más dosis hoy): next-dose es null.
        final result = computeDoseState(null, now, locallyMissedDose: missed);
        expect(result.state, DoseVisualState.notTaken);
      },
    );

    test(
      'dosis perdida localmente pero next-dose ya avanzó a otra ocurrencia -> notTaken',
      () {
        final now = DateTime.now().toUtc();
        final missed = MissedDoseSnapshot(
          doseScheduleId: 1,
          scheduledAtUtc: now.subtract(const Duration(minutes: 20)),
          medicationName: 'Losartán',
          dose: '50mg',
        );
        final nextOccurrence = _dose(
          scheduledAtUtc: now.add(const Duration(hours: 8)),
        );

        final result = computeDoseState(
          nextOccurrence,
          now,
          locallyMissedDose: missed,
        );
        expect(result.state, DoseVisualState.notTaken);
      },
    );

    test(
      'dosis perdida localmente pero next-dose YA es esa misma ocurrencia resuelta -> no fuerza notTaken',
      () {
        final now = DateTime.now().toUtc();
        final scheduledAt = now.subtract(const Duration(minutes: 20));
        final missed = MissedDoseSnapshot(
          doseScheduleId: 1,
          scheduledAtUtc: scheduledAt,
          medicationName: 'Losartán',
          dose: '50mg',
        );
        // Mismo doseScheduleId y mismo scheduledAtUtc que el "missed": el
        // snapshot local ya no aplica, se evalúa el estado real normalmente.
        final sameOccurrence = _dose(scheduledAtUtc: scheduledAt);

        final result = computeDoseState(
          sameOccurrence,
          now,
          locallyMissedDose: missed,
        );
        expect(result.state, isNot(DoseVisualState.notTaken));
      },
    );
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

    test(
      'parsea scheduledAtUtc con offset explícito (no solo Z) correctamente',
      () {
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
      },
    );
  });
}
