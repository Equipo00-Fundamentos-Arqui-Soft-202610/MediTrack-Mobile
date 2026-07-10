class AppConstants {
  static const int patientId = 1;

  // Centralized MediTrack API Gateway base URL.
  static const String gatewayBaseUrl = 'https://meditrack-gateway.onrender.com';

  static const String baseUrl = gatewayBaseUrl;

  static const String followUpBaseUrl = '$gatewayBaseUrl/followup/api/v1';
  static const String treatmentBaseUrl = '$gatewayBaseUrl/treatment/api/v1';
  static const String appointmentsBaseUrl =
      '$gatewayBaseUrl/appointments/api/v1';
}