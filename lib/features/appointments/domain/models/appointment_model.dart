class AppointmentModel {
  final int id;
  final int patientId;
  final String type;
  final DateTime scheduledAt;
  final String? location;
  final String? notes;
  final String status;
  final bool canBeModified;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<AppointmentRequirementModel> requirements;

  const AppointmentModel({
    required this.id,
    required this.patientId,
    required this.type,
    required this.scheduledAt,
    required this.location,
    required this.notes,
    required this.status,
    required this.canBeModified,
    required this.createdAt,
    required this.updatedAt,
    required this.requirements,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    final requirementsJson = json['requirements'] as List<dynamic>? ?? [];

    return AppointmentModel(
      id: json['id'] as int,
      patientId: json['patientId'] as int,
      type: json['type']?.toString() ?? 'Cita médica',
      scheduledAt: DateTime.parse(json['scheduledAt'].toString()),
      location: json['location']?.toString(),
      notes: json['notes']?.toString(),
      status: json['status']?.toString() ?? 'scheduled',
      canBeModified: json['canBeModified'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString()),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'].toString()),
      requirements: requirementsJson
          .map(
            (item) => AppointmentRequirementModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class AppointmentRequirementModel {
  final int id;
  final String description;

  const AppointmentRequirementModel({
    required this.id,
    required this.description,
  });

  factory AppointmentRequirementModel.fromJson(Map<String, dynamic> json) {
    return AppointmentRequirementModel(
      id: json['id'] as int,
      description: json['description']?.toString() ?? '',
    );
  }
}
