import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  /// `POST /identity/api/v1/profile/photo` (multipart/form-data, campo
  /// `photo`): sube o reemplaza la foto de perfil. El backend resuelve al
  /// dueño desde el JWT y devuelve el perfil actualizado.
  Future<Map<String, dynamic>> uploadProfilePhoto(File photoFile) async {
    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(photoFile.path),
      });

      final response = await _dio.post(
        '${AppConstants.identityBaseUrl}/profile/photo',
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _debugLogFailure('POST /profile/photo', e);
      throw mapDioException(e);
    }
  }

  /// `DELETE /identity/api/v1/profile/photo`: elimina la foto de perfil
  /// actual (si existe) y devuelve el perfil actualizado.
  Future<Map<String, dynamic>> deleteProfilePhoto() async {
    try {
      final response = await _dio.delete('${AppConstants.identityBaseUrl}/profile/photo');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _debugLogFailure('DELETE /profile/photo', e);
      throw mapDioException(e);
    }
  }

  void _debugLogFailure(String endpoint, DioException e) {
    debugPrint(
      'AuthService $endpoint failed: status=${e.response?.statusCode} body=${e.response?.data}',
    );
  }
}
