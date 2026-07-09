class AppConstants {
  static const int patientId = 1;

  // Centralized MediTrack API Gateway base URL.
  // Android Emulator uses 10.0.2.2 as the alias for the host machine's localhost.
  static const String gatewayBaseUrl = 'http://10.0.2.2:5000';

  static const String baseUrl = gatewayBaseUrl;

  static const String followUpBaseUrl = '$gatewayBaseUrl/followup/api/v1';
  static const String treatmentBaseUrl = '$gatewayBaseUrl/treatment/api/v1';
  static const String appointmentsBaseUrl =
      '$gatewayBaseUrl/appointments/api/v1';
}