import 'package:dio/dio.dart';
import 'package:meditrack_mobile/core/constants/app_constants.dart';
import 'package:meditrack_mobile/core/network/api_client.dart';
import 'package:meditrack_mobile/core/network/api_exception.dart';

class AdherenceService {
  final Dio _dio = ApiClient.instance.dio;

  Future<double> getAdherencePercentage(int patientId) async {
    try {
      final response = await _dio.get(
        '${AppConstants.followUpBaseUrl}/medications/adherence-history',
        queryParameters: {'patientId': patientId},
      );
      final data = response.data as Map<String, dynamic>;
      return (data['overallAdherencePercentage'] as num).toDouble();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return 0;
      throw mapDioException(e);
    }
  }

  /// Contrato real confirmado en FollowUp-Service:
  /// `GET /api/v1/compliance?patientId=&limit=` (no existe `/compliance/recent`).
  Future<List<dynamic>> getRecentCompliance({
    required int patientId,
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        '${AppConstants.followUpBaseUrl}/compliance',
        queryParameters: {'patientId': patientId, 'limit': limit},
      );
      return response.data as List<dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw mapDioException(e);
    }
  }

  Future<List<dynamic>> getMedications(int patientId) async {
    try {
      final response = await _dio.get(
        '${AppConstants.followUpBaseUrl}/medications',
        queryParameters: {'patientId': patientId},
      );
      return response.data as List<dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw mapDioException(e);
    }
  }
}
