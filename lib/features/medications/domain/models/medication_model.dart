class MedicationModel {
  final int id;
  final int prescriptionId;
  final int catalogId;
  final String officialName;
  final String? category;
  final String dose;
  final int frequencyHours;
  final DateTime startDate;
  final DateTime? endDate;
  final int stockCount;
  final int stockAlertThreshold;
  final bool isActive;
  final List<String> scheduledTimes;

  MedicationModel({
    required this.id,
    required this.prescriptionId,
    required this.catalogId,
    required this.officialName,
    required this.category,
    required this.dose,
    required this.frequencyHours,
    required this.startDate,
    required this.endDate,
    required this.stockCount,
    required this.stockAlertThreshold,
    required this.isActive,
    required this.scheduledTimes,
  });

  factory MedicationModel.fromJson(Map<String, dynamic> json) {
    return MedicationModel(
      id: json['id'],
      prescriptionId: json['prescriptionId'],
      catalogId: json['catalogId'],
      officialName: json['officialName'],
      category: json['category'],
      dose: json['dose'],
      frequencyHours: json['frequencyHours'],
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      stockCount: json['stockCount'],
      stockAlertThreshold: json['stockAlertThreshold'],
      // Treatment-service devuelve TODOS los medicamentos (activos e
      // inactivos); el filtro por activos se hace en el cliente.
      isActive: json['isActive'] as bool? ?? true,
      scheduledTimes: List<String>.from(json['scheduledTimes'] ?? []),
    );
  }
}
