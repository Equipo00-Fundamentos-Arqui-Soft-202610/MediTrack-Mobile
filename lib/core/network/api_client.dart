import 'package:dio/dio.dart';
import 'package:meditrack_mobile/core/constants/app_constants.dart';

/// Cliente HTTP único para todo MediTrack-Mobile, apuntando al API Gateway.
///
/// Cada servicio arma su ruta completa con el segmento real del gateway
/// (ej. `/followup/api/v1/...`, `/treatment/api/v1/...`), pero comparte este
/// mismo [Dio] para no repetir la lógica de headers/errores en cada uno.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.gatewayBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final hadToken = error.requestOptions.headers.containsKey('Authorization');
          if (error.response?.statusCode == 401 && hadToken) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;
  String? _token;

  /// Registrado por main.dart: se dispara cuando el gateway rechaza una
  /// request autenticada con 401 (token vencido/inválido), para limpiar la
  /// sesión local y redirigir a Login.
  void Function()? onUnauthorized;

  Dio get dio => _dio;

  void setToken(String? token) {
    _token = token;
  }
}
