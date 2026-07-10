import 'package:dio/dio.dart';
import 'package:meditrack_mobile/core/constants/app_constants.dart';
import 'package:meditrack_mobile/core/network/api_client.dart';
import 'package:meditrack_mobile/core/network/api_exception.dart';
import 'package:meditrack_mobile/features/appointments/domain/models/appointment_model.dart';
import 'package:meditrack_mobile/features/appointments/domain/models/clinical_exam_model.dart';

class AppointmentService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<AppointmentModel>> getAppointmentsByPatientId(
    int patientId,
  ) async {
    try {
      final response = await _dio.get(
        '${AppConstants.appointmentsBaseUrl}/appointments/patient/$patientId',
      );
      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((item) => AppointmentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<AppointmentModel> createAppointment({
    required int patientId,
    required String type,
    required DateTime scheduledAt,
    String? location,
    String? notes,
    List<String>? requirements,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConstants.appointmentsBaseUrl}/appointments',
        data: {
          'patientId': patientId,
          'type': type,
          'scheduledAt': scheduledAt.toIso8601String(),
          'location': location,
          'notes': notes,
          'requirements': requirements,
        },
      );
      return AppointmentModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<AppointmentModel> updateAppointment({
    required int id,
    required String type,
    required DateTime scheduledAt,
    String? location,
    String? notes,
    List<String>? requirements,
  }) async {
    try {
      final response = await _dio.put(
        '${AppConstants.appointmentsBaseUrl}/appointments/$id',
        data: {
          'type': type,
          'scheduledAt': scheduledAt.toIso8601String(),
          'location': location,
          'notes': notes,
          'requirements': requirements,
        },
      );
      return AppointmentModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<AppointmentModel> cancelAppointment(int id) async {
    try {
      final response = await _dio.patch(
        '${AppConstants.appointmentsBaseUrl}/appointments/$id/cancel',
      );
      return AppointmentModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<List<ClinicalExamModel>> getPendingClinicalExams(int patientId) async {
    try {
      final response = await _dio.get(
        '${AppConstants.appointmentsBaseUrl}/clinical-exams/pending',
        queryParameters: {'patientId': patientId},
      );
      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((item) => ClinicalExamModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw mapDioException(e);
    }
  }
}
