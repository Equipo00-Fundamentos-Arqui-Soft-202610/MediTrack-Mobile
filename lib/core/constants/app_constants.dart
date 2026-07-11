class AppConstants {
  // Centralized MediTrack API Gateway base URL.
  // Defaults to production; override for local emulator testing with:
  //   flutter run --dart-define=GATEWAY_URL=http://10.0.2.2:5000
  static const String gatewayBaseUrl = String.fromEnvironment(
    'GATEWAY_URL',
    defaultValue: 'https://meditrack-gateway.onrender.com',
  );

  static const String baseUrl = gatewayBaseUrl;

  static const String identityBaseUrl = '$gatewayBaseUrl/identity/api/v1';
  static const String followUpBaseUrl = '$gatewayBaseUrl/followup/api/v1';
  static const String treatmentBaseUrl = '$gatewayBaseUrl/treatment/api/v1';
  static const String appointmentsBaseUrl =
      '$gatewayBaseUrl/appointments/api/v1';

  /// Cada cuánto se consulta /compliance/{id}/status mientras se espera
  /// validación (pantalla de evidencia abierta).
  static const int complianceStatusPollingSeconds = 10;

  // Ciclo escalonado de recordatorios de una dosis (alarma inicial + 2 avisos
  // + cierre a T+10 si el paciente nunca actúa). Todos los offsets son
  // relativos al horario exacto de la dosis (T+0 = scheduledAtUtc). Esta
  // misma ventana (hasta T+10) es también la "ventana de toma": cuánto
  // tiempo sigue habilitado "Tomar dosis" y hasta cuándo se puede reintentar
  // tras un Rejected — unificada con el cierre del ciclo para no dejar la UI
  // ofreciendo una acción que el backend (`StaleDoseExpirationService`) ya
  // cerró.
  //
  //   T+0                                     -> alarma inicial
  //   T+doseReminderSecondAlarmOffsetMinutes   -> 2do aviso
  //   T+doseReminderThirdAlarmOffsetMinutes    -> 3er y último aviso
  //   T+doseReminderCloseOffsetMinutes         -> cierre: fin de la ventana de
  //                                              toma/reintento; si no hubo
  //                                              evidencia, el backend la
  //                                              registra como no tomada.
  static const int doseReminderSecondAlarmOffsetMinutes = 4;
  static const int doseReminderThirdAlarmOffsetMinutes = 7;
  static const int doseReminderCloseOffsetMinutes = 10;
}
