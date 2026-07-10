class AppConstants {
  // Centralized MediTrack API Gateway base URL.
  // Android Emulator uses 10.0.2.2 as the alias for the host machine's localhost.
  static const String gatewayBaseUrl = 'http://10.0.2.2:5000';

  static const String baseUrl = gatewayBaseUrl;

  static const String identityBaseUrl = '$gatewayBaseUrl/identity/api/v1';
  static const String followUpBaseUrl = '$gatewayBaseUrl/followup/api/v1';
  static const String treatmentBaseUrl = '$gatewayBaseUrl/treatment/api/v1';
  static const String appointmentsBaseUrl =
      '$gatewayBaseUrl/appointments/api/v1';

  /// Tolerancia posterior al horario programado durante la cual el botón
  /// "Tomar dosis" sigue habilitado (la ventana empieza en el horario exacto).
  static const int takeDoseToleranceMinutes = 60;

  /// Cada cuánto se consulta /compliance/{id}/status mientras se espera
  /// validación (pantalla de evidencia abierta).
  static const int complianceStatusPollingSeconds = 10;
}