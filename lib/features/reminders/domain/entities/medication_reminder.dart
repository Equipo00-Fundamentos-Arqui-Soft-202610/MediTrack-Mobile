class MedicationReminder {
  final int medicationId;
  final String medicationName;
  final String dose;
  final List<String> scheduledTimes;

  const MedicationReminder({
    required this.medicationId,
    required this.medicationName,
    required this.dose,
    required this.scheduledTimes,
  });
}
