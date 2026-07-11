import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack_mobile/core/network/api_client.dart';
import 'package:meditrack_mobile/features/auth/data/services/auth_service.dart';

/// Captura la última request enviada por Dio y devuelve una respuesta fija,
/// sin tocar la red — verifica que AuthService.register arma el body con los
/// nombres de campo reales del contrato mobile de Identity-Service
/// (MobileRegisterRequest: nombre, email, password, rol, institucion, dni,
/// fechaNacimiento).
class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final body = utf8.encode(
      jsonEncode({
        'accessToken': 'tok-test',
        'usuario': {
          'id': 1,
          'nombre': 'Ana',
          'email': 'ana@test.com',
          'rol': 'paciente',
          'institucion': null,
          'phoneNumber': null,
          'profilePhotoUrl': null,
          'dni': '12345678',
          'fechaNacimiento': '1995-04-12T00:00:00.000',
        },
      }),
    );
    return ResponseBody.fromBytes(
      body,
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('AuthService.register — contrato real de Identity-Service', () {
    late _RecordingAdapter adapter;

    setUp(() {
      adapter = _RecordingAdapter();
      ApiClient.instance.dio.httpClientAdapter = adapter;
    });

    test(
      'envía dni y fechaNacimiento con los nombres exactos del backend',
      () async {
        final authService = AuthService();

        final response = await authService.register(
          nombre: 'Ana Paciente',
          email: 'ana@test.com',
          password: 'password123',
          dni: '12345678',
          fechaNacimiento: DateTime(1995, 4, 12),
        );

        final sentData = adapter.lastRequest!.data as Map<String, dynamic>;
        expect(sentData['nombre'], 'Ana Paciente');
        expect(sentData['email'], 'ana@test.com');
        expect(sentData['password'], 'password123');
        expect(sentData['rol'], 'paciente');
        expect(sentData['dni'], '12345678');
        expect(
          sentData['fechaNacimiento'],
          DateTime(1995, 4, 12).toIso8601String(),
        );

        final usuario = response['usuario'] as Map<String, dynamic>;
        expect(usuario['dni'], '12345678');
        expect(usuario['fechaNacimiento'], isNotNull);
      },
    );

    test(
      'sin dni/fechaNacimiento, los envía como null (no los omite)',
      () async {
        final authService = AuthService();

        await authService.register(
          nombre: 'Sin Datos',
          email: 'sindatos@test.com',
          password: 'password123',
        );

        final sentData = adapter.lastRequest!.data as Map<String, dynamic>;
        expect(sentData.containsKey('dni'), isTrue);
        expect(sentData['dni'], isNull);
        expect(sentData.containsKey('fechaNacimiento'), isTrue);
        expect(sentData['fechaNacimiento'], isNull);
      },
    );
  });
}
