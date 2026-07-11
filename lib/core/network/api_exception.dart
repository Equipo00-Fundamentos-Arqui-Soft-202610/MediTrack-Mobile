import 'package:dio/dio.dart';

/// Excepción uniforme para toda llamada al API Gateway.
///
/// Los backends de MediTrack devuelven dos formatos de error distintos:
/// `{"message": "..."}` para errores de negocio, o `ValidationProblemDetails`
/// de ASP.NET (`{"title": ..., "errors": {...}}`) para fallos de validación
/// automáticos. Esta clase homogeniza ambos en un mensaje legible.
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

ApiException mapDioException(DioException error) {
  final response = error.response;

  if (response == null) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          null,
          'La conexión tardó demasiado. Intenta de nuevo.',
        );
      case DioExceptionType.connectionError:
        return ApiException(
          null,
          'No se pudo conectar con el servidor. Verifica tu conexión o que el API Gateway esté activo.',
        );
      default:
        return ApiException(null, 'Ocurrió un error de red inesperado.');
    }
  }

  final statusCode = response.statusCode;
  final data = response.data;
  String? message;

  if (data is Map) {
    final rawMessage = data['message'];
    final rawTitle = data['title'];
    final rawErrors = data['errors'];

    if (rawMessage is String && rawMessage.isNotEmpty) {
      message = rawMessage;
    } else if (rawErrors is Map) {
      message = rawErrors.values
          .expand((value) => value is List ? value : [value])
          .map((value) => value.toString())
          .join('\n');
    } else if (rawTitle is String && rawTitle.isNotEmpty) {
      message = rawTitle;
    }
  }

  switch (statusCode) {
    case 400:
      return ApiException(400, message ?? 'Solicitud inválida.');
    case 401:
      return ApiException(
        401,
        message ?? 'Sesión expirada. Inicia sesión nuevamente.',
      );
    case 404:
      return ApiException(
        404,
        message ?? 'No se encontró la información solicitada.',
      );
    case 409:
      return ApiException(409, message ?? 'El recurso ya existe.');
    case 500:
      return ApiException(
        500,
        message ?? 'Error interno del servidor. Intenta más tarde.',
      );
    default:
      return ApiException(
        statusCode,
        message ?? 'Ocurrió un error inesperado ($statusCode).',
      );
  }
}
