import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meditrack_mobile/features/appointments/domain/models/appointment_model.dart';

class AppointmentService {
  static const String baseUrl = 'http://10.0.2.2:5268/api/v1';

  Future<List<AppointmentModel>> getAppointmentsByPatientId(
    int patientId,
  ) async {
    final uri = Uri.parse('$baseUrl/appointments/patient/$patientId');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Error cargando citas: ${response.statusCode} - ${response.body}',
      );
    }

    final List<dynamic> data = jsonDecode(response.body);

    return data
        .map((item) => AppointmentModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
