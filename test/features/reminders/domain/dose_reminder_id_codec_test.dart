import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack_mobile/features/reminders/domain/dose_reminder_id_codec.dart';

void main() {
  group('DoseReminderIdCodec', () {
    test(
      'genera 3 IDs distintos para la misma ocurrencia (inicial, 2do, 3er aviso)',
      () {
        final scheduledAtUtc = DateTime.utc(2026, 7, 11, 13, 0, 0);
        final ids = DoseReminderIdCodec.buildCycle(
          doseScheduleId: 200,
          scheduledAtUtc: scheduledAtUtc,
        );

        expect(ids.length, 3);
        expect(
          ids.toSet().length,
          3,
          reason: 'los 3 IDs del mismo ciclo deben ser únicos entre sí',
        );
      },
    );

    test('es determinístico: mismos inputs -> mismos IDs', () {
      final scheduledAtUtc = DateTime.utc(2026, 7, 11, 13, 0, 0);
      final first = DoseReminderIdCodec.buildCycle(
        doseScheduleId: 200,
        scheduledAtUtc: scheduledAtUtc,
      );
      final second = DoseReminderIdCodec.buildCycle(
        doseScheduleId: 200,
        scheduledAtUtc: scheduledAtUtc,
      );

      expect(first, second);
    });

    test(
      'distingue dosis/schedule: doseScheduleId distinto -> IDs distintos',
      () {
        final scheduledAtUtc = DateTime.utc(2026, 7, 11, 13, 0, 0);
        final a = DoseReminderIdCodec.build(
          doseScheduleId: 200,
          scheduledAtUtc: scheduledAtUtc,
          attempt: 0,
        );
        final b = DoseReminderIdCodec.build(
          doseScheduleId: 201,
          scheduledAtUtc: scheduledAtUtc,
          attempt: 0,
        );

        expect(a, isNot(b));
      },
    );

    test(
      'distingue la fecha de la ocurrencia: mismo horario, día distinto -> IDs distintos',
      () {
        final day1 = DateTime.utc(2026, 7, 11, 13, 0, 0);
        final day2 = DateTime.utc(2026, 7, 12, 13, 0, 0);
        final a = DoseReminderIdCodec.build(
          doseScheduleId: 200,
          scheduledAtUtc: day1,
          attempt: 0,
        );
        final b = DoseReminderIdCodec.build(
          doseScheduleId: 200,
          scheduledAtUtc: day2,
          attempt: 0,
        );

        expect(a, isNot(b));
      },
    );

    test('distingue el número de intento', () {
      final scheduledAtUtc = DateTime.utc(2026, 7, 11, 13, 0, 0);
      final initial = DoseReminderIdCodec.build(
        doseScheduleId: 200,
        scheduledAtUtc: scheduledAtUtc,
        attempt: DoseReminderIdCodec.initialAttempt,
      );
      final second = DoseReminderIdCodec.build(
        doseScheduleId: 200,
        scheduledAtUtc: scheduledAtUtc,
        attempt: DoseReminderIdCodec.secondAttempt,
      );
      final third = DoseReminderIdCodec.build(
        doseScheduleId: 200,
        scheduledAtUtc: scheduledAtUtc,
        attempt: DoseReminderIdCodec.thirdAttempt,
      );

      expect({initial, second, third}.length, 3);
    });

    test(
      'los IDs generados caben siempre en Int32 (límite de los plugins nativos)',
      () {
        const int int32Max = 2147483647;
        for (final doseScheduleId in [1, 200, 999, 19999, 123456789]) {
          for (final dayOffset in [0, 1, 4, 365, 5000]) {
            final scheduledAtUtc = DateTime.utc(
              2024,
              1,
              1,
            ).add(Duration(days: dayOffset));
            for (final attempt in [0, 1, 2]) {
              for (final kind in [
                DoseReminderIdCodec.kindAlarm,
                DoseReminderIdCodec.kindNotification,
              ]) {
                final id = DoseReminderIdCodec.build(
                  doseScheduleId: doseScheduleId,
                  scheduledAtUtc: scheduledAtUtc,
                  attempt: attempt,
                  kind: kind,
                );
                expect(id, greaterThan(0));
                expect(id, lessThan(int32Max));
              }
            }
          }
        }
      },
    );

    test(
      'el namespace de alarma y el de notificación nunca colisionan para la misma ocurrencia/intento',
      () {
        final scheduledAtUtc = DateTime.utc(2026, 7, 11, 13, 0, 0);
        for (final doseScheduleId in [1, 200, 999, 19999, 123456789]) {
          for (final attempt in [0, 1, 2]) {
            final alarmId = DoseReminderIdCodec.build(
              doseScheduleId: doseScheduleId,
              scheduledAtUtc: scheduledAtUtc,
              attempt: attempt,
              kind: DoseReminderIdCodec.kindAlarm,
            );
            final notificationId = DoseReminderIdCodec.build(
              doseScheduleId: doseScheduleId,
              scheduledAtUtc: scheduledAtUtc,
              attempt: attempt,
              kind: DoseReminderIdCodec.kindNotification,
            );
            expect(alarmId, isNot(notificationId));
          }
        }
      },
    );

    test(
      'buildCycle con kindNotification genera 3 IDs de notificación distintos y sin pisar los de alarma',
      () {
        final scheduledAtUtc = DateTime.utc(2026, 7, 11, 13, 0, 0);
        final alarmIds = DoseReminderIdCodec.buildCycle(
          doseScheduleId: 200,
          scheduledAtUtc: scheduledAtUtc,
        );
        final notificationIds = DoseReminderIdCodec.buildCycle(
          doseScheduleId: 200,
          scheduledAtUtc: scheduledAtUtc,
          kind: DoseReminderIdCodec.kindNotification,
        );

        expect(notificationIds.toSet().length, 3);
        expect(alarmIds.toSet().intersection(notificationIds.toSet()), isEmpty);
      },
    );
  });
}
