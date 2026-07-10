import 'package:dio/dio.dart';
import 'package:meditrack_mobile/core/constants/app_constants.dart';
import 'package:meditrack_mobile/core/network/api_client.dart';
import 'package:meditrack_mobile/core/network/api_exception.dart';

import '../../domain/models/medication_model.dart';

class MedicationService {
  final Dio _dio = ApiClient.instance.dio;

  /// Contrato real confirmado en Treatment-service:
  /// `GET /api/v1/medications?patientId=` (no `/medications/patient/{id}`).
  /// El endpoint devuelve TODOS los medicamentos del paciente (activos e
  /// inactivos/cancelados) — se filtra `isActive` aquí en el cliente.
  Future<List<MedicationModel>> getMedicationsByPatientId(int patientId) async {
    try {
      final response = await _dio.get(
        '${AppConstants.treatmentBaseUrl}/medications',
        queryParameters: {'patientId': patientId},
      );

      final List<dynamic> jsonList = response.data as List<dynamic>;

      return jsonList
          .map((json) => MedicationModel.fromJson(json as Map<String, dynamic>))
          .where((medication) => medication.isActive)
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw mapDioException(e);
    }
  }
}
