import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:meditrack_mobile/core/constants/app_constants.dart';

class AdherenceService {
  static const String followUpBaseUrl = AppConstants.followUpBaseUrl;

  Future<double> getAdherencePercentage(int patientId) async {
    final url = Uri.parse(
      '$followUpBaseUrl/medications/adherence-history?patientId=$patientId',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 8));

    debugPrint('ADHERENCE HISTORY STATUS: ${response.statusCode}');
    debugPrint('ADHERENCE HISTORY BODY: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['overallAdherencePercentage'] as num).toDouble();
    }

    if (response.statusCode == 404) return 0;

    throw Exception('Error loading adherence percentage');
  }

  Future<List<dynamic>> getRecentCompliance({
    required int patientId,
    int limit = 10,
  }) async {
    final url = Uri.parse(
      '$followUpBaseUrl/compliance/recent?patientId=$patientId&limit=$limit',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 8));

    debugPrint('RECENT COMPLIANCE STATUS: ${response.statusCode}');
    debugPrint('RECENT COMPLIANCE BODY: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    if (response.statusCode == 404) return [];

    throw Exception('Error loading recent compliance');
  }

  Future<List<dynamic>> getMedications(int patientId) async {
    final url = Uri.parse('$followUpBaseUrl/medications?patientId=$patientId');

    final response = await http.get(url).timeout(const Duration(seconds: 8));

    debugPrint('MEDICATIONS STATUS: ${response.statusCode}');
    debugPrint('MEDICATIONS BODY: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    if (response.statusCode == 404) return [];

    throw Exception('Error loading medications');
  }
}
