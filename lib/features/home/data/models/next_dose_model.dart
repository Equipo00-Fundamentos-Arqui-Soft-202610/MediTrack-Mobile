class NextDoseModel {
  final int doseScheduleId;
  final String medicationName;
  final String dose;
  final String scheduledTime;
  final int minutesUntilDose;

  /// Instante real (UTC) de la ocurrencia de hoy, enviado por el backend —
  /// se usa para calcular la ventana de toma sin horas hardcodeadas.
  final DateTime scheduledAtUtc;

  /// Si ya existe un intento de evidencia para la dosis de hoy.
  final int? complianceId;

  /// "PendingValidation" | "Rejected" | null (sin intento todavía).
  final String? validationStatus;
  final String? rejectionReason;

  NextDoseModel({
    required this.doseScheduleId,
    required this.medicationName,
    required this.dose,
    required this.scheduledTime,
    required this.minutesUntilDose,
    required this.scheduledAtUtc,
    required this.complianceId,
    required this.validationStatus,
    required this.rejectionReason,
  });

  bool get isPendingValidation => validationStatus == 'PendingValidation';
  bool get isRejected => validationStatus == 'Rejected';

  factory NextDoseModel.fromJson(Map<String, dynamic> json) {
    return NextDoseModel(
      doseScheduleId: json['doseScheduleId'] as int,
      medicationName: json['medicationName'] as String,
      dose: json['dose'] as String,
      scheduledTime: json['scheduledTime'] as String,
      minutesUntilDose: json['minutesUntilDose'] as int,
      scheduledAtUtc: DateTime.parse(json['scheduledAtUtc'] as String).toUtc(),
      complianceId: json['complianceId'] as int?,
      validationStatus: json['validationStatus'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }
}
