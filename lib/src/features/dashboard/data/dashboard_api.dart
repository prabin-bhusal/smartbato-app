import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../../core/network/secure_http_client.dart';

import '../../../core/config/api_config.dart';
import '../models/dashboard_home_data.dart';

class DashboardApi {
  final http.Client _client = SecureHttpClient();

  Future<DashboardHomeData> fetchHomeData(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/dashboard/home');

    late final http.Response response;

    try {
      response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } on SocketException {
      throw Exception(
        'Network required. Please check your internet connection.',
      );
    }

    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to load dashboard data.');
    }

    return DashboardHomeData.fromJson(data);
  }

  Map<String, dynamic> _decode(String responseBody) {
    if (responseBody.isEmpty) {
      return <String, dynamic>{};
    }

    return jsonDecode(responseBody) as Map<String, dynamic>;
  }
}
