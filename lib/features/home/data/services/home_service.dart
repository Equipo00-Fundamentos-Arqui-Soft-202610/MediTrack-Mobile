import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/next_dose_model.dart';

class HomeService {
  static const String followUpBaseUrl = 'http://10.0.2.2:5267/api/v1';
  static const String treatmentBaseUrl = 'http://10.0.2.2:5000/api/v1';

  Future<NextDoseModel?> getNextDose(int patientId) async {
    final url = Uri.parse(
      '$followUpBaseUrl/medications/next-dose?patientId=$patientId',
    );

    final response = await http.get(url);

    print('NEXT DOSE STATUS: ${response.statusCode}');
    print('NEXT DOSE BODY: ${response.body}');

    if (response.statusCode == 200) {
      if (response.body.isEmpty) return null;

      final data = jsonDecode(response.body);
      return NextDoseModel.fromJson(data);
    }

    if (response.statusCode == 404) {
      return null;
    }

    throw Exception('Error loading next dose');
  }

  Future<double> getAdherencePercentage(int patientId) async {
    final url = Uri.parse(
      '$followUpBaseUrl/medications/adherence-history?patientId=$patientId',
    );

    final response = await http.get(url);

    print('ADHERENCE STATUS: ${response.statusCode}');
    print('ADHERENCE BODY: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['overallAdherencePercentage'] as num).toDouble();
    }

    if (response.statusCode == 404) {
      return 0;
    }

    throw Exception('Error loading adherence percentage');
  }

  Future<void> takeDose({
    required int patientId,
    required int doseScheduleId,
  }) async {
    final url = Uri.parse('$followUpBaseUrl/compliance?patientId=$patientId');

    final body = {
      'patientId': patientId,
      'doseScheduleId': doseScheduleId,
      'status': 'taken',
      'videoUrl': null,
      'offlineRecordedAt': null,
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error registering dose');
    }
  }

  Future<List<dynamic>> getLowStockMedications(int patientId) async {
    final url = Uri.parse('$treatmentBaseUrl/medications/patient/$patientId');

    final response = await http.get(url);

    print('LOW STOCK/TREATMENT STATUS: ${response.statusCode}');
    print('LOW STOCK/TREATMENT BODY: ${response.body}');

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);

      return data.where((medication) {
        final stockCount = medication['stockCount'] ?? 0;
        final threshold = medication['stockAlertThreshold'] ?? 0;
        final isActive = medication['isActive'] ?? true;

        return isActive == true && stockCount <= threshold;
      }).toList();
    }

    throw Exception('Error loading low stock medications');
  }
}
