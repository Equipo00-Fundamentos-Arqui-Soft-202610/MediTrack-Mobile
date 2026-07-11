import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meditrack_mobile/core/notifications/push_notification_service.dart';
import 'package:meditrack_mobile/core/session/session_controller.dart';
import 'package:meditrack_mobile/core/session/session_storage.dart';
import 'package:meditrack_mobile/features/auth/data/services/auth_service.dart';
import 'package:meditrack_mobile/features/auth/presentation/screens/register_screen.dart';

/// Fake sin Firebase: el registro completo llega a `_persist`, que se
/// suscribe al topic del paciente — sin este fake tocaría
/// `PushNotificationService.instance` real (`FirebaseMessaging.instance`).
class _FakePushNotificationService implements PushNotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> subscribeToPatientTopic(int patientId) async {}

  @override
  Future<void> unsubscribeFromPatientTopic(int patientId) async {}
}

class _FakeAuthService extends AuthService {
  Map<String, dynamic>? lastRequest;

  @override
  Future<Map<String, dynamic>> register({
    required String nombre,
    required String email,
    required String password,
    String rol = 'paciente',
    String? institucion,
    String? dni,
    DateTime? fechaNacimiento,
  }) async {
    lastRequest = {
      'nombre': nombre,
      'email': email,
      'password': password,
      'rol': rol,
      'dni': dni,
      'fechaNacimiento': fechaNacimiento,
    };
    return {
      'accessToken': 'tok-test',
      'usuario': {
        'id': 1,
        'nombre': nombre,
        'email': email,
        'rol': 'paciente',
        'institucion': null,
        'phoneNumber': null,
        'profilePhotoUrl': null,
        'dni': dni,
        'fechaNacimiento': fechaNacimiento?.toIso8601String(),
      },
    };
  }
}

class _InMemorySessionStorage extends SessionStorage {
  @override
  Future<void> save({
    required String token,
    required Map<String, dynamic> user,
  }) async {}

  @override
  Future<String?> readToken() async => null;

  @override
  Future<Map<String, dynamic>?> readUser() async => null;

  @override
  Future<void> clear() async {}
}

Future<void> _pumpRegisterScreen(
  WidgetTester tester,
  SessionController controller,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SessionController>.value(
      value: controller,
      child: const MaterialApp(home: RegisterScreen()),
    ),
  );
}

/// El AppBar y el botón de envío comparten el mismo texto "Crear cuenta";
/// este finder ubica únicamente el botón.
final _submitButtonFinder = find.widgetWithText(ElevatedButton, 'Crear cuenta');

void main() {
  group('RegisterScreen — validaciones de DNI y fecha de nacimiento', () {
    testWidgets('formulario vacío muestra errores de validación en español', (
      tester,
    ) async {
      final controller = SessionController(
        storage: _InMemorySessionStorage(),
        authService: _FakeAuthService(),
      );

      await _pumpRegisterScreen(tester, controller);
      await tester.tap(_submitButtonFinder);
      await tester.pump();

      expect(find.text('Ingresa tu nombre'), findsOneWidget);
      expect(find.text('Ingresa tu correo'), findsOneWidget);
      expect(find.text('Ingresa tu DNI'), findsOneWidget);
      expect(find.text('Selecciona tu fecha de nacimiento'), findsOneWidget);
      expect(find.text('Ingresa una contraseña'), findsOneWidget);
    });

    testWidgets('DNI con menos de 8 dígitos muestra error y no envía', (
      tester,
    ) async {
      final authService = _FakeAuthService();
      final controller = SessionController(
        storage: _InMemorySessionStorage(),
        authService: authService,
      );

      await _pumpRegisterScreen(tester, controller);
      await tester.enterText(find.widgetWithText(TextFormField, 'DNI'), '123');
      await tester.tap(_submitButtonFinder);
      await tester.pump();

      expect(find.text('El DNI debe tener 8 dígitos'), findsOneWidget);
      expect(authService.lastRequest, isNull);
    });

    testWidgets('el selector de fecha no permite elegir fechas futuras', (
      tester,
    ) async {
      final controller = SessionController(
        storage: _InMemorySessionStorage(),
        authService: _FakeAuthService(),
      );

      await _pumpRegisterScreen(tester, controller);
      await tester.tap(find.text('Selecciona una fecha'));
      await tester.pumpAndSettle();

      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      final now = DateTime.now();
      expect(
        dialog.lastDate.isBefore(now.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    testWidgets(
      'registro completo con DNI de 8 dígitos y fecha de nacimiento envía los datos reales',
      (tester) async {
        final authService = _FakeAuthService();
        final controller = SessionController(
          storage: _InMemorySessionStorage(),
          authService: authService,
          pushNotificationService: _FakePushNotificationService(),
        );

        await _pumpRegisterScreen(tester, controller);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre completo'),
          'Ana Paciente',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Correo electrónico'),
          'ana@test.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'DNI'),
          '12345678',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Contraseña'),
          'password123',
        );

        // Selecciona la fecha de nacimiento vía el DatePicker real: el valor
        // inicial ya es una fecha pasada válida (hoy - 18 años), así que basta
        // con confirmar sin navegar el calendario.
        await tester.tap(find.text('Selecciona una fecha'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();

        await tester.tap(_submitButtonFinder);
        await tester.pumpAndSettle();

        expect(authService.lastRequest, isNotNull);
        expect(authService.lastRequest!['nombre'], 'Ana Paciente');
        expect(authService.lastRequest!['dni'], '12345678');
        expect(authService.lastRequest!['fechaNacimiento'], isA<DateTime>());
        expect(controller.isAuthenticated, isTrue);
        expect(controller.current!.dni, '12345678');
      },
    );
  });
}
