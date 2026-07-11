import 'package:shared_preferences/shared_preferences.dart';

/// Persiste la solicitud de "Tomar dosis" que llega al tocar la acción
/// explícita `TAKE_DOSE` de una notificación (`flutter_local_notifications`).
///
/// Es deliberadamente un almacén simple basado en `shared_preferences` (no
/// una clase con estado en memoria) porque el toque puede procesarse en un
/// isolate en segundo plano completamente distinto del isolate principal
/// (app terminada) — no hay forma de compartir una variable en memoria entre
/// ambos, así que la única forma confiable de que la UI (Home) se entere más
/// tarde es leyendo algo persistido en disco.
class PendingDoseActionStore {
  PendingDoseActionStore._();

  static const _doseScheduleIdKey = 'meditrack_pending_take_dose_schedule_id';
  static const _scheduledAtUtcKey =
      'meditrack_pending_take_dose_scheduled_at_utc';

  /// Registra que se tocó "Tomar dosis" para esta ocurrencia. Seguro de
  /// llamar desde cualquier isolate (foreground, background, o el callback
  /// de app terminada), siempre que se haya llamado antes
  /// `WidgetsFlutterBinding.ensureInitialized()` en ese isolate.
  static Future<void> persist({
    required int doseScheduleId,
    required DateTime scheduledAtUtc,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_doseScheduleIdKey, doseScheduleId);
    await prefs.setString(
      _scheduledAtUtcKey,
      scheduledAtUtc.toUtc().toIso8601String(),
    );
  }

  /// Si hay una solicitud pendiente que coincide exactamente con
  /// [doseScheduleId]/[scheduledAtUtc], la consume (borra) y devuelve `true`.
  /// Si no coincide, la deja intacta (podría corresponder a una dosis futura
  /// que Home todavía no cargó) y devuelve `false`.
  static Future<bool> consumeIfMatches(
    int doseScheduleId,
    DateTime scheduledAtUtc,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getInt(_doseScheduleIdKey);
    final storedAt = prefs.getString(_scheduledAtUtcKey);
    if (storedId == null || storedAt == null) return false;

    final matches =
        storedId == doseScheduleId &&
        DateTime.parse(storedAt).isAtSameMomentAs(scheduledAtUtc.toUtc());
    if (!matches) return false;

    await prefs.remove(_doseScheduleIdKey);
    await prefs.remove(_scheduledAtUtcKey);
    return true;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_doseScheduleIdKey);
    await prefs.remove(_scheduledAtUtcKey);
  }
}
