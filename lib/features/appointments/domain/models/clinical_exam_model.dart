/// Contrato real confirmado en Medical-Appointment-Service (ClinicalExamResource).
class ClinicalExamModel {
  final int id;
  final int patientId;
  final int? appointmentId;
  final String examType;
  final DateTime? scheduledDate;
  final DateTime? pickupDate;
  final String status; // "pending" | "ready" | "collected"

  const ClinicalExamModel({
    required this.id,
    required this.patientId,
    required this.appointmentId,
    required this.examType,
    required this.scheduledDate,
    required this.pickupDate,
    required this.status,
  });

  factory ClinicalExamModel.fromJson(Map<String, dynamic> json) {
    return ClinicalExamModel(
      id: json['id'] as int,
      patientId: json['patientId'] as int,
      appointmentId: json['appointmentId'] as int?,
      examType: json['examType']?.toString() ?? 'Examen',
      scheduledDate: json['scheduledDate'] == null
          ? null
          : DateTime.tryParse(json['scheduledDate'].toString()),
      pickupDate: json['pickupDate'] == null
          ? null
          : DateTime.tryParse(json['pickupDate'].toString()),
      status: json['status']?.toString() ?? 'pending',
    );
  }
}
