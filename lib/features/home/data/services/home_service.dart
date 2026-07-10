import 'package:dio/dio.dart';
import 'package:meditrack_mobile/core/constants/app_constants.dart';
import 'package:meditrack_mobile/core/network/api_client.dart';
import 'package:meditrack_mobile/core/network/api_exception.dart';

import '../models/next_dose_model.dart';

class HomeService {
  final Dio _dio = ApiClient.instance.dio;

  Future<NextDoseModel?> getNextDose(int patientId) async {
    try {
      final response = await _dio.get(
        '${AppConstants.followUpBaseUrl}/medications/next-dose',
        queryParameters: {'patientId': patientId},
      );
      return NextDoseModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw mapDioException(e);
    }
  }

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

  Future<void> takeDose({
    required int patientId,
    required int doseScheduleId,
  }) async {
    try {
      await _dio.post(
        '${AppConstants.followUpBaseUrl}/compliance',
        queryParameters: {'patientId': patientId},
        data: {
          'doseScheduleId': doseScheduleId,
          'status': 'taken',
          'videoUrl': null,
          'offlineRecordedAt': null,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<List<dynamic>> getLowStockMedications(int patientId) async {
    try {
      final response = await _dio.get(
        '${AppConstants.treatmentBaseUrl}/medications',
        queryParameters: {'patientId': patientId},
      );
      final List data = response.data as List;

      return data.where((medication) {
        final stockCount = medication['stockCount'] ?? 0;
        final threshold = medication['stockAlertThreshold'] ?? 0;
        final isActive = medication['isActive'] ?? true;

        return isActive == true && stockCount <= threshold;
      }).toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
