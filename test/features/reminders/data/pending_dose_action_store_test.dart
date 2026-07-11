import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meditrack_mobile/features/reminders/data/pending_dose_action_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PendingDoseActionStore', () {
    test('persiste y consume una solicitud que coincide exactamente', () async {
      final scheduledAtUtc = DateTime.utc(2026, 7, 11, 13, 0, 0);
      await PendingDoseActionStore.persist(
        doseScheduleId: 200,
        scheduledAtUtc: scheduledAtUtc,
      );

      final matched = await PendingDoseActionStore.consumeIfMatches(
        200,
        scheduledAtUtc,
      );

      expect(matched, isTrue);
    });

    test(
      'consumir borra la solicitud (no se puede volver a consumir)',
      () async {
        final scheduledAtUtc = DateTime.utc(2026, 7, 11, 13, 0, 0);
        await PendingDoseActionStore.persist(
          doseScheduleId: 200,
          scheduledAtUtc: scheduledAtUtc,
        );

        await PendingDoseActionStore.consumeIfMatches(200, scheduledAtUtc);
        final secondAttempt = await PendingDoseActionStore.consumeIfMatches(
          200,
          scheduledAtUtc,
        );

        expect(secondAttempt, isFalse);
      },
    );

    test('no coincide con un doseScheduleId distinto y no la borra', () async {
      final scheduledAtUtc = DateTime.utc(2026, 7, 11, 13, 0, 0);
      await PendingDoseActionStore.persist(
        doseScheduleId: 200,
        scheduledAtUtc: scheduledAtUtc,
      );

      final matched = await PendingDoseActionStore.consumeIfMatches(
        999,
        scheduledAtUtc,
      );
      expect(matched, isFalse);

      // Sigue disponible para la ocurrencia correcta (Home puede no haberla
      // cargado todavía cuando llega este toque).
      final stillMatches = await PendingDoseActionStore.consumeIfMatches(
        200,
        scheduledAtUtc,
      );
      expect(stillMatches, isTrue);
    });

    test(
      'no coincide con la misma dosis en una fecha/ocurrencia distinta',
      () async {
        final scheduledAtUtc = DateTime.utc(2026, 7, 11, 13, 0, 0);
        await PendingDoseActionStore.persist(
          doseScheduleId: 200,
          scheduledAtUtc: scheduledAtUtc,
        );

        final matched = await PendingDoseActionStore.consumeIfMatches(
          200,
          scheduledAtUtc.add(const Duration(days: 1)),
        );

        expect(matched, isFalse);
      },
    );

    test('sin ninguna solicitud pendiente, no coincide con nada', () async {
      final matched = await PendingDoseActionStore.consumeIfMatches(
        1,
        DateTime.utc(2026, 1, 1),
      );
      expect(matched, isFalse);
    });
  });
}
