import 'package:meditrack_mobile/core/alarms/medication_alarm_service.dart';
import 'package:meditrack_mobile/features/medications/domain/models/medication_model.dart';

class MedicationAlarmScheduler {
  MedicationAlarmScheduler({required MedicationAlarmService alarmService})
    : _alarmService = alarmService;

  final MedicationAlarmService _alarmService;

  Future<void> scheduleMedicationAlarms(
    List<MedicationModel> medications,
  ) async {
    for (final medication in medications) {
      for (final scheduledTime in medication.scheduledTimes) {
        final parsedTime = _parseScheduledTime(scheduledTime);

        if (parsedTime == null) continue;

        final alarmId = _buildAlarmId(
          medication.id,
          parsedTime.hour,
          parsedTime.minute,
        );

        await _alarmService.scheduleMedicationAlarm(
          alarmId: alarmId,
          medicationName: medication.officialName,
          dose: medication.dose,
          hour: parsedTime.hour,
          minute: parsedTime.minute,
        );
      }
    }
  }

  int _buildAlarmId(int medicationId, int hour, int minute) {
    return int.parse(
      '$medicationId${hour.toString().padLeft(2, '0')}${minute.toString().padLeft(2, '0')}',
    );
  }

  _ParsedTime? _parseScheduledTime(String value) {
    final parts = value.split(':');

    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23) return null;
    if (minute < 0 || minute > 59) return null;

    return _ParsedTime(hour: hour, minute: minute);
  }
}

class _ParsedTime {
  final int hour;
  final int minute;

  const _ParsedTime({required this.hour, required this.minute});
}
