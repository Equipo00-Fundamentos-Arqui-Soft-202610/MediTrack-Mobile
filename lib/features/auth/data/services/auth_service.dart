import 'package:dio/dio.dart';
import 'package:meditrack_mobile/core/constants/app_constants.dart';
import 'package:meditrack_mobile/core/network/api_client.dart';
import 'package:meditrack_mobile/core/network/api_exception.dart';

/// Contrato real confirmado en Identity-Service (AuthController/ProfileController):
/// login/register devuelven { accessToken, usuario: {id,nombre,email,rol,institucion} }.
class AuthService {
  final Dio _dio = ApiClient.instance.dio;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConstants.identityBaseUrl}/auth/login',
        data: {'email': email, 'password': password},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// [rol] es "paciente" por defecto; Identity-Service también acepta
  /// "Doctor"/"TechnicalStaff"/"Admin" (con [institucion] opcional) para el
  /// registro de personal técnico (IAM-RF2).
  Future<Map<String, dynamic>> register({
    required String nombre,
    required String email,
    required String password,
    String rol = 'paciente',
    String? institucion,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConstants.identityBaseUrl}/auth/register',
        data: {
          'nombre': nombre,
          'email': email,
          'password': password,
          'rol': rol,
          'institucion': institucion,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get('${AppConstants.identityBaseUrl}/profile');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    String? nombre,
    String? email,
    String? institucion,
    String? phoneNumber,
    String? profilePhotoUrl,
  }) async {
    try {
      final response = await _dio.put(
        '${AppConstants.identityBaseUrl}/profile',
        data: {
          'nombre': nombre,
          'email': email,
          'institucion': institucion,
          'phoneNumber': phoneNumber,
          'profilePhotoUrl': profilePhotoUrl,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// `PUT /identity/api/v1/profile/password`: valida la contraseña actual en
  /// el backend antes de aplicar la nueva.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.put(
        '${AppConstants.identityBaseUrl}/profile/password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
