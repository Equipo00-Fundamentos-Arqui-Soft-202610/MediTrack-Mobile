import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:meditrack_mobile/features/reminders/domain/models/dose_reminder_cycle.dart';

/// Persistencia local (no sensible) de los ciclos de recordatorio de dosis
/// activos, para poder reconstruirlos y cancelarlos tras cerrar/reabrir la
/// app o reiniciar el dispositivo — las alarmas nativas sobreviven por sí
/// solas, pero sin esto el coordinador no sabría qué alarmas ya programó ni
/// en qué estado quedó cada ciclo.
class DoseReminderStorage {
  static const _storageKey = 'meditrack_dose_reminder_cycles';

  Future<List<DoseReminderCycle>> loadCycles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List;
    return decoded
        .map((item) => DoseReminderCycle.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCycles(List<DoseReminderCycle> cycles) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(cycles.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> upsertCycle(DoseReminderCycle cycle) async {
    final cycles = await loadCycles();
    final index = cycles.indexWhere(
      (c) => c.occurrenceKey == cycle.occurrenceKey,
    );
    if (index >= 0) {
      cycles[index] = cycle;
    } else {
      cycles.add(cycle);
    }
    await saveCycles(cycles);
  }

  Future<void> removeCycle(String occurrenceKey) async {
    final cycles = await loadCycles();
    cycles.removeWhere((c) => c.occurrenceKey == occurrenceKey);
    await saveCycles(cycles);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
