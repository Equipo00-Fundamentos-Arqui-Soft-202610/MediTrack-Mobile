import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack_mobile/core/session/session_controller.dart';
import 'package:meditrack_mobile/core/session/session_storage.dart';
import 'package:meditrack_mobile/features/auth/data/services/auth_service.dart';

/// MediTrack-Mobile es exclusivamente para pacientes: estos tests cubren el
/// bloqueo de acceso completo (no solo ocultar pantallas) para cualquier
/// usuario cuyo rol no sea paciente, en los tres puntos de entrada: login,
/// registro y restauración de una sesión guardada.
class _FakeAuthService extends AuthService {
  Map<String, dynamic>? loginResponse;
  Map<String, dynamic>? registerResponse;
  Map<String, dynamic>? profileResponse;

  @override
  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    return loginResponse!;
  }

  @override
  Future<Map<String, dynamic>> register({
    required String nombre,
    required String email,
    required String password,
    String rol = 'paciente',
    String? institucion,
  }) async {
    return registerResponse!;
  }

  @override
  Future<Map<String, dynamic>> getProfile() async {
    return profileResponse!;
  }
}

/// `flutter_secure_storage` usa un MethodChannel real que cuelga en
/// `flutter test` — se reemplaza por un mapa en memoria (mismo criterio ya
/// usado en test/widget_test.dart con `_NoopSessionStorage`).
class _InMemorySessionStorage extends SessionStorage {
  String? _token;
  Map<String, dynamic>? _user;
  bool cleared = false;

  @override
  Future<void> save({required String token, required Map<String, dynamic> user}) async {
    _token = token;
    _user = user;
    cleared = false;
  }

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<Map<String, dynamic>?> readUser() async => _user;

  @override
  Future<void> clear() async {
    _token = null;
    _user = null;
    cleared = true;
  }
}

Map<String, dynamic> _usuario({
  required int id,
  required String nombre,
  required String email,
  required String rol,
}) => {
      'id': id,
      'nombre': nombre,
      'email': email,
      'rol': rol,
      'institucion': null,
      'phoneNumber': null,
      'profilePhotoUrl': null,
    };

void main() {
  group('SessionController — acceso exclusivo para pacientes', () {
    test('login con paciente guarda la sesión normalmente', () async {
      final storage = _InMemorySessionStorage();
      final authService = _FakeAuthService()
        ..loginResponse = {
          'accessToken': 'tok-paciente',
          'usuario': _usuario(id: 1, nombre: 'Ana', email: 'ana@test.com', rol: 'paciente'),
        };
      final controller = SessionController(storage: storage, authService: authService);

      await controller.login(email: 'ana@test.com', password: 'x');

      expect(controller.isAuthenticated, isTrue);
      expect(controller.current!.rol, 'paciente');
      expect(await storage.readToken(), 'tok-paciente');
    });

    test('login con TechnicalStaff lanza NotAPatientException y no persiste sesión', () async {
      final storage = _InMemorySessionStorage();
      final authService = _FakeAuthService()
        ..loginResponse = {
          'accessToken': 'tok-staff',
          'usuario': _usuario(id: 2, nombre: 'Tec', email: 'tec@test.com', rol: 'TechnicalStaff'),
        };
      final controller = SessionController(storage: storage, authService: authService);

      await expectLater(
        controller.login(email: 'tec@test.com', password: 'x'),
        throwsA(
          isA<NotAPatientException>().having(
            (e) => e.message,
            'message',
            SessionController.patientOnlyMessage,
          ),
        ),
      );

      expect(controller.isAuthenticated, isFalse);
      expect(await storage.readToken(), isNull);
    });

    test('una sesión guardada de TechnicalStaff se purga al restaurar, con mensaje de bloqueo', () async {
      final storage = _InMemorySessionStorage();
      await storage.save(
        token: 'tok-restored',
        user: {..._usuario(id: 3, nombre: 'Doc', email: 'doc@test.com', rol: 'Doctor'), 'patientId': null},
      );
      final authService = _FakeAuthService()
        ..profileResponse = _usuario(id: 3, nombre: 'Doc', email: 'doc@test.com', rol: 'Doctor');
      final controller = SessionController(storage: storage, authService: authService);

      await controller.restoreSession();

      expect(controller.isAuthenticated, isFalse);
      expect(storage.cleared, isTrue);
      expect(controller.consumeBlockedMessage(), SessionController.patientOnlyMessage);
      // Una vez consumido, no debe repetirse en un segundo chequeo.
      expect(controller.consumeBlockedMessage(), isNull);
    });

    test('restoreSession con sesión de paciente guardada no bloquea nada', () async {
      final storage = _InMemorySessionStorage();
      await storage.save(
        token: 'tok-ok',
        user: {..._usuario(id: 4, nombre: 'Ana', email: 'ana@test.com', rol: 'paciente'), 'patientId': 4},
      );
      final authService = _FakeAuthService()
        ..profileResponse = _usuario(id: 4, nombre: 'Ana', email: 'ana@test.com', rol: 'paciente');
      final controller = SessionController(storage: storage, authService: authService);

      await controller.restoreSession();

      expect(controller.isAuthenticated, isTrue);
      expect(storage.cleared, isFalse);
      expect(controller.consumeBlockedMessage(), isNull);
    });

    test('register siempre crea un paciente (rol forzado, sin selector en la UI)', () async {
      final storage = _InMemorySessionStorage();
      final authService = _FakeAuthService()
        ..registerResponse = {
          'accessToken': 'tok-nuevo',
          'usuario': _usuario(id: 5, nombre: 'Nuevo', email: 'nuevo@test.com', rol: 'paciente'),
        };
      final controller = SessionController(storage: storage, authService: authService);

      await controller.register(nombre: 'Nuevo', email: 'nuevo@test.com', password: '123456');

      expect(controller.isAuthenticated, isTrue);
      expect(controller.current!.isPaciente, isTrue);
    });
  });
}
