import 'package:meditrack_mobile/core/notifications/local_notification_service.dart';
import 'package:meditrack_mobile/features/reminders/domain/entities/medication_reminder.dart';

class MedicationReminderScheduler {
  MedicationReminderScheduler({
    required LocalNotificationService notificationService,
  }) : _notificationService = notificationService;

  final LocalNotificationService _notificationService;

  Future<void> scheduleMedicationReminders(
    List<MedicationReminder> reminders,
  ) async {
    for (final reminder in reminders) {
      for (final scheduledTime in reminder.scheduledTimes) {
        final parsedTime = _parseScheduledTime(scheduledTime);

        if (parsedTime == null) continue;

        final notificationId = _buildNotificationId(
          reminder.medicationId,
          parsedTime.hour,
          parsedTime.minute,
        );

        await _notificationService.scheduleDailyMedicationNotification(
          notificationId: notificationId,
          medicationName: reminder.medicationName,
          dose: reminder.dose,
          hour: parsedTime.hour,
          minute: parsedTime.minute,
        );
      }
    }
  }

  Future<void> rescheduleMedicationReminders(
    List<MedicationReminder> reminders,
  ) async {
    await _notificationService.cancelAllNotifications();
    await scheduleMedicationReminders(reminders);
  }

  int _buildNotificationId(int medicationId, int hour, int minute) {
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
