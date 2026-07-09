import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meditrack_mobile/core/constants/app_constants.dart';

import '../../domain/models/medication_model.dart';

class MedicationService {
  static const String baseUrl = AppConstants.treatmentBaseUrl;

  Future<List<MedicationModel>> getMedicationsByPatientId(int patientId) async {
    final uri = Uri.parse('$baseUrl/medications/patient/$patientId');

    final client = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

    final request = await client.getUrl(uri);
    final response = await request.close();

    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      throw Exception('Error al obtener medicamentos: $responseBody');
    }

    final List<dynamic> jsonList = json.decode(responseBody);

    return jsonList
        .map((json) => MedicationModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
