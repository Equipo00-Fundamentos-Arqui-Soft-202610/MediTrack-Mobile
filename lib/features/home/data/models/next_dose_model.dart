class NextDoseModel {
  final int doseScheduleId;
  final String medicationName;
  final String dose;
  final String scheduledTime;
  final int minutesUntilDose;

  NextDoseModel({
    required this.doseScheduleId,
    required this.medicationName,
    required this.dose,
    required this.scheduledTime,
    required this.minutesUntilDose,
  });

  factory NextDoseModel.fromJson(Map<String, dynamic> json) {
    return NextDoseModel(
      doseScheduleId: json['doseScheduleId'],
      medicationName: json['medicationName'],
      dose: json['dose'],
      scheduledTime: json['scheduledTime'],
      minutesUntilDose: json['minutesUntilDose'],
    );
  }
}
