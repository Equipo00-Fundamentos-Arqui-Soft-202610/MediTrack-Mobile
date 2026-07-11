import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:meditrack_mobile/core/network/api_client.dart';
import 'package:meditrack_mobile/core/network/api_exception.dart';
import 'package:meditrack_mobile/core/notifications/push_notification_service.dart';
import 'package:meditrack_mobile/core/session/jwt_utils.dart';
import 'package:meditrack_mobile/core/session/session_storage.dart';
import 'package:meditrack_mobile/features/auth/data/services/auth_service.dart';
import 'package:meditrack_mobile/features/auth/domain/models/user_session.dart';

/// Lanzada cuando login/registro/restauración de sesión resuelven un usuario
/// cuyo rol no es paciente. MediTrack-Mobile es exclusivamente para
/// pacientes: nunca se persiste sesión ni token para estos casos.
class NotAPatientException implements Exception {
  final String message;
  const NotAPatientException(this.message);

  @override
  String toString() => message;
}

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
  SessionController({
    SessionStorage? storage,
    AuthService? authService,
    PushNotificationService? pushNotificationService,
  }) : _storage = storage ?? SessionStorage(),
       _authService = authService ?? AuthService(),
       _pushNotificationServiceOverride = pushNotificationService;

  /// MediTrack-Mobile es exclusivamente para pacientes: se muestra tal cual
  /// cuando login/registro/restauración de sesión detectan un rol distinto.
  /// No basta con ocultar pantallas — se bloquea el acceso completo.
  static const String patientOnlyMessage =
      'Esta aplicación móvil está disponible únicamente para pacientes.';

  final SessionStorage _storage;
  final AuthService _authService;

  /// Sin inyectar en producción: se resuelve perezosamente contra
  /// `PushNotificationService.instance` solo cuando de verdad se necesita
  /// (dentro de `_persist`/`restoreSession`), no en el constructor — así
  /// construir un `SessionController` nunca toca Firebase por sí solo (clave
  /// para poder testear todo lo que no dependa de push notifications sin
  /// tener que inyectar un fake en cada test).
  final PushNotificationService? _pushNotificationServiceOverride;
  PushNotificationService get _pushNotificationService =>
      _pushNotificationServiceOverride ?? PushNotificationService.instance;

  UserSession? _current;
  bool _isRestoring = true;

  /// Mensaje pendiente de mostrar tras un bloqueo detectado en
  /// [restoreSession] (arranque de la app, sin pantalla de Login todavía
  /// montada). LoginScreen lo consume una sola vez vía [consumeBlockedMessage].
  String? blockedMessage;

  UserSession? get current => _current;
  bool get isAuthenticated => _current != null;
  bool get isRestoring => _isRestoring;
  int? get patientId => _current?.patientId;

  /// Se llama desde LoginScreen para mostrar (una sola vez) el motivo por el
  /// que una sesión guardada fue cerrada durante [restoreSession].
  String? consumeBlockedMessage() {
    final msg = blockedMessage;
    blockedMessage = null;
    return msg;
  }

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
      phoneNumber: usuario['phoneNumber'] as String?,
      profilePhotoUrl: usuario['profilePhotoUrl'] as String?,
      patientId: _resolvePatientId(token, usuario),
      dni: usuario['dni'] as String?,
      fechaNacimiento: usuario['fechaNacimiento'] != null
          ? DateTime.parse(usuario['fechaNacimiento'] as String)
          : null,
    );
  }

  /// Se llama una única vez al arrancar la app. Si hay un token guardado,
  /// lo valida contra `GET /profile`; si el backend lo rechaza (401), limpia
  /// la sesión local. También re-valida el rol: una sesión guardada de un
  /// usuario que ya no es paciente (o que nunca lo fue) se cierra aquí,
  /// dejando [blockedMessage] listo para que Login lo muestre.
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
        phoneNumber: profile['phoneNumber'] as String?,
        profilePhotoUrl: profile['profilePhotoUrl'] as String?,
        patientId: storedUser['patientId'] as int?,
        dni: profile['dni'] as String?,
        fechaNacimiento: profile['fechaNacimiento'] != null
            ? DateTime.parse(profile['fechaNacimiento'] as String)
            : null,
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

    final restored = _current;
    if (restored != null && !restored.isPaciente) {
      await _clearLocalSession();
      blockedMessage = patientOnlyMessage;
    } else if (restored?.patientId != null) {
      await _pushNotificationService.subscribeToPatientTopic(
        restored!.patientId!,
      );
    }

    _isRestoring = false;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    final response = await _authService.login(email: email, password: password);
    final session = _buildSession(response);
    if (!session.isPaciente) {
      // No se persistió nada todavía, pero se limpia por si quedó algún
      // token temporal (defensivo: bloqueo debe ser total, no solo visual).
      ApiClient.instance.setToken(null);
      throw const NotAPatientException(patientOnlyMessage);
    }
    await _persist(session);
  }

  /// MediTrack-Mobile es solo para pacientes: el rol siempre es "paciente",
  /// sin excepción ni opción en la UI (no se registra personal técnico desde
  /// esta app). El backend devuelve token igual que en login, así que se
  /// auto-loguea tras registrarse. La verificación de rol se repite aquí
  /// como defensa adicional, aunque el rol ya se manda fijo.
  Future<void> register({
    required String nombre,
    required String email,
    required String password,
    required String dni,
    required DateTime fechaNacimiento,
  }) async {
    final response = await _authService.register(
      nombre: nombre,
      email: email,
      password: password,
      rol: 'paciente',
      institucion: null,
      dni: dni,
      fechaNacimiento: fechaNacimiento,
    );
    final session = _buildSession(response);
    if (!session.isPaciente) {
      ApiClient.instance.setToken(null);
      throw const NotAPatientException(patientOnlyMessage);
    }
    await _persist(session);
  }

  Future<void> updateProfile({
    String? nombre,
    String? email,
    String? institucion,
    String? phoneNumber,
    String? profilePhotoUrl,
  }) async {
    final updated = await _authService.updateProfile(
      nombre: nombre,
      email: email,
      institucion: institucion,
      phoneNumber: phoneNumber,
      profilePhotoUrl: profilePhotoUrl,
    );
    await _applyUpdatedProfile(updated);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _authService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Sube o reemplaza la foto de perfil. Si el backend rechaza el archivo
  /// (formato/tamaño) o falla la red, la excepción se propaga sin tocar la
  /// sesión actual — la foto anterior sigue vigente y el usuario NO se
  /// desloguea.
  Future<void> uploadProfilePhoto(File photoFile) async {
    final updated = await _authService.uploadProfilePhoto(photoFile);
    await _applyUpdatedProfile(updated);
  }

  /// Elimina la foto de perfil actual (si existe). Mismo criterio de fallos
  /// que [uploadProfilePhoto]: no afecta la sesión si el backend rechaza.
  Future<void> deleteProfilePhoto() async {
    final updated = await _authService.deleteProfilePhoto();
    await _applyUpdatedProfile(updated);
  }

  Future<void> _applyUpdatedProfile(Map<String, dynamic> updated) async {
    final current = _current;
    if (current == null) return;

    _current = UserSession(
      token: current.token,
      id: updated['id'] as int,
      nombre: updated['nombre'] as String,
      email: updated['email'] as String,
      rol: updated['rol'] as String,
      institucion: updated['institucion'] as String?,
      phoneNumber: updated['phoneNumber'] as String?,
      profilePhotoUrl: updated['profilePhotoUrl'] as String?,
      patientId: current.patientId,
      dni: updated['dni'] as String? ?? current.dni,
      fechaNacimiento: updated['fechaNacimiento'] != null
          ? DateTime.parse(updated['fechaNacimiento'] as String)
          : current.fechaNacimiento,
    );
    await _storage.save(token: current.token, user: _current!.toStorageJson());
    notifyListeners();
  }

  Future<void> _persist(UserSession session) async {
    ApiClient.instance.setToken(session.token);
    await _storage.save(token: session.token, user: session.toStorageJson());
    _current = session;
    if (session.patientId != null) {
      await _pushNotificationService.subscribeToPatientTopic(
        session.patientId!,
      );
    }
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

  /// Solo para tests: fija una sesión directamente sin pasar por red/storage.
  @visibleForTesting
  void debugSetSession(UserSession session) {
    _current = session;
    _isRestoring = false;
    notifyListeners();
  }
}
