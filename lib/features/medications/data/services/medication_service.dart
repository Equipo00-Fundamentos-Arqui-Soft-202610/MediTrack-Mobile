import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meditrack_mobile/core/constants/app_constants.dart';

import '../../domain/models/medication_model.dart';

class MedicationService {
  static const String baseUrl = AppConstants.treatmentBaseUrl;

  Future<List<MedicationModel>> getMedicationsByPatientId(int patientId) async {
    // Treatment-service expone patientId como query param, no como segmento
    // de ruta (GetMedicationsByPatientId([FromQuery] int patientId)).
    final uri = Uri.parse('$baseUrl/medications?patientId=$patientId');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Error al obtener medicamentos: ${response.body}');
    }

    final List<dynamic> jsonList = json.decode(response.body);

    return jsonList
        .map((json) => MedicationModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
