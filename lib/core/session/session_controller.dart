import 'package:flutter/foundation.dart';
import 'package:meditrack_mobile/core/network/api_client.dart';
import 'package:meditrack_mobile/core/network/api_exception.dart';
import 'package:meditrack_mobile/core/session/jwt_utils.dart';
import 'package:meditrack_mobile/core/session/session_storage.dart';
import 'package:meditrack_mobile/features/auth/data/services/auth_service.dart';
import 'package:meditrack_mobile/features/auth/domain/models/user_session.dart';

/// Fuente única de verdad de la sesión del usuario logueado.
///
/// Resolución de `patientId` (no existe en el body de login/perfil de
/// Identity-Service, solo como claim OPCIONAL del JWT):
/// 1) Si el JWT trae el claim `patientId`, se usa ese.
/// 2) TODO(backend): Identity-Service todavía no vincula un `Patient` real al
///    registrar un usuario (`RegisterRequest` no asigna `PatientId`), así que
///    como resguardo temporal se usa el `id` del propio usuario. Esto asume
///    que las bases de datos de los microservicios de dominio (Treatment,
///    FollowUp, Appointments) tienen un paciente con ese mismo id — es una
///    suposición de entorno de pruebas, no una garantía real. Cuando
///    Identity-Service exponga la vinculación real, reemplazar este fallback
///    aquí (único lugar centralizado, según lo pedido).
class SessionController extends ChangeNotifier {
  SessionController({SessionStorage? storage, AuthService? authService})
      : _storage = storage ?? SessionStorage(),
        _authService = authService ?? AuthService();

  final SessionStorage _storage;
  final AuthService _authService;

  UserSession? _current;
  bool _isRestoring = true;

  UserSession? get current => _current;
  bool get isAuthenticated => _current != null;
  bool get isRestoring => _isRestoring;
  int? get patientId => _current?.patientId;

  int? _resolvePatientId(String token, Map<String, dynamic> usuario) {
    try {
      final claims = decodeJwtPayload(token);
      final claim = claims['patientId'];
      if (claim != null) {
        return claim is int ? claim : int.tryParse(claim.toString());
      }
    } catch (_) {
      // Token sin claims decodificables: seguimos con el fallback.
    }
    // TODO(backend): fallback documentado arriba — usar id de Identity
    // mientras no exista vínculo real Patient<->User.
    return usuario['id'] as int?;
  }

  UserSession _buildSession(Map<String, dynamic> authResponse) {
    final token = authResponse['accessToken'] as String;
    final usuario = authResponse['usuario'] as Map<String, dynamic>;
    return UserSession(
      token: token,
      id: usuario['id'] as int,
      nombre: usuario['nombre'] as String,
      email: usuario['email'] as String,
      rol: usuario['rol'] as String,
      institucion: usuario['institucion'] as String?,
      patientId: _resolvePatientId(token, usuario),
    );
  }

  /// Se llama una única vez al arrancar la app. Si hay un token guardado,
  /// lo valida contra `GET /profile`; si el backend lo rechaza (401), limpia
  /// la sesión local.
  Future<void> restoreSession() async {
    final token = await _storage.readToken();
    final storedUser = await _storage.readUser();

    if (token == null || storedUser == null) {
      _isRestoring = false;
      notifyListeners();
      return;
    }

    ApiClient.instance.setToken(token);

    try {
      final profile = await _authService.getProfile();
      _current = UserSession(
        token: token,
        id: profile['id'] as int,
        nombre: profile['nombre'] as String,
        email: profile['email'] as String,
        rol: profile['rol'] as String,
        institucion: profile['institucion'] as String?,
        patientId: storedUser['patientId'] as int?,
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _clearLocalSession();
      } else {
        // Backend no disponible u otro error transitorio: mantenemos la
        // sesión guardada localmente para no expulsar al usuario sin motivo.
        _current = UserSession.fromStorageJson(token, storedUser);
      }
    }

    _isRestoring = false;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    final response = await _authService.login(email: email, password: password);
    final session = _buildSession(response);
    await _persist(session);
  }

  /// Registro (paciente o personal técnico según [rol]/[institucion]).
  /// El backend devuelve token igual que en login, así que se auto-loguea.
  Future<void> register({
    required String nombre,
    required String email,
    required String password,
    String rol = 'paciente',
    String? institucion,
  }) async {
    final response = await _authService.register(
      nombre: nombre,
      email: email,
      password: password,
      rol: rol,
      institucion: institucion,
    );
    final session = _buildSession(response);
    await _persist(session);
  }

  Future<void> updateProfile({String? nombre, String? email, String? institucion}) async {
    final updated = await _authService.updateProfile(
      nombre: nombre,
      email: email,
      institucion: institucion,
    );
    final current = _current;
    if (current == null) return;

    _current = UserSession(
      token: current.token,
      id: updated['id'] as int,
      nombre: updated['nombre'] as String,
      email: updated['email'] as String,
      rol: updated['rol'] as String,
      institucion: updated['institucion'] as String?,
      patientId: current.patientId,
    );
    await _storage.save(token: current.token, user: _current!.toStorageJson());
    notifyListeners();
  }

  Future<void> _persist(UserSession session) async {
    ApiClient.instance.setToken(session.token);
    await _storage.save(token: session.token, user: session.toStorageJson());
    _current = session;
    notifyListeners();
  }

  Future<void> _clearLocalSession() async {
    ApiClient.instance.setToken(null);
    await _storage.clear();
    _current = null;
  }

  Future<void> logout() async {
    await _clearLocalSession();
    notifyListeners();
  }
}
