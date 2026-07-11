import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack_mobile/features/reminders/domain/models/take_dose_notification_payload.dart';

void main() {
  group('TakeDoseNotificationPayload', () {
    test('codifica y decodifica de forma exacta (roundtrip)', () {
      final scheduledAtUtc = DateTime.utc(2026, 7, 11, 13, 0, 0);
      final original = TakeDoseNotificationPayload(
        doseScheduleId: 200,
        scheduledAtUtc: DateTime.utc(2026, 7, 11, 13, 0, 0),
        alarmId: 123456,
      );

      final decoded = TakeDoseNotificationPayload.tryParse(original.encode());

      expect(decoded, isNotNull);
      expect(decoded!.doseScheduleId, 200);
      expect(decoded.scheduledAtUtc, scheduledAtUtc);
      expect(decoded.alarmId, 123456);
    });

    test(
      'identifica de forma segura la ocurrencia y el intento correcto (distintos alarmId por aviso)',
      () {
        final scheduledAtUtc = DateTime.utc(2026, 7, 11, 13, 0, 0);
        final initial = TakeDoseNotificationPayload(
          doseScheduleId: 200,
          scheduledAtUtc: scheduledAtUtc,
          alarmId: 111,
        ).encode();
        final second = TakeDoseNotificationPayload(
          doseScheduleId: 200,
          scheduledAtUtc: scheduledAtUtc,
          alarmId: 222,
        ).encode();

        final decodedInitial = TakeDoseNotificationPayload.tryParse(initial)!;
        final decodedSecond = TakeDoseNotificationPayload.tryParse(second)!;

        // Mismo doseScheduleId/ocurrencia, pero alarmId distinto por intento —
        // así "Tomar dosis" solo detiene LA alarma de ese aviso puntual.
        expect(decodedInitial.doseScheduleId, decodedSecond.doseScheduleId);
        expect(decodedInitial.scheduledAtUtc, decodedSecond.scheduledAtUtc);
        expect(decodedInitial.alarmId, isNot(decodedSecond.alarmId));
      },
    );

    test(
      'payload nulo, vacío o malformado -> null (no revienta ni asume valores)',
      () {
        expect(TakeDoseNotificationPayload.tryParse(null), isNull);
        expect(TakeDoseNotificationPayload.tryParse(''), isNull);
        expect(TakeDoseNotificationPayload.tryParse('solo-una-parte'), isNull);
        expect(TakeDoseNotificationPayload.tryParse('a|b|c'), isNull);
        expect(
          TakeDoseNotificationPayload.tryParse('200|no-es-una-fecha|123'),
          isNull,
        );
      },
    );
  });
}
