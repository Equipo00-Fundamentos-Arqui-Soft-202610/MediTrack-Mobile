class AppConstants {
  static const int patientId = 1;

  // Centralized MediTrack API Gateway base URL.
  // Defaults to production; override for local emulator testing with:
  //   flutter run --dart-define=GATEWAY_URL=http://10.0.2.2:5000
  static const String gatewayBaseUrl = String.fromEnvironment(
    'GATEWAY_URL',
    defaultValue: 'https://meditrack-gateway.onrender.com',
  );

  static const String baseUrl = gatewayBaseUrl;

  static const String followUpBaseUrl = '$gatewayBaseUrl/followup/api/v1';
  static const String treatmentBaseUrl = '$gatewayBaseUrl/treatment/api/v1';
  static const String appointmentsBaseUrl =
      '$gatewayBaseUrl/appointments/api/v1';
}