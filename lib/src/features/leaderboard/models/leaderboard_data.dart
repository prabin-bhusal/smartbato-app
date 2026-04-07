import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/network/secure_http_client.dart';
import '../../../core/config/api_config.dart';

class LeaderboardApi {
  final http.Client _client = SecureHttpClient();

  Future<Map<String, dynamic>> fetchLeaderboard({
    required String token,
    required String tab,
    int page = 1,
    int perPage = 20,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/leaderboard?tab=$tab&page=$page&per_page=$perPage',
    );
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
      throw Exception(data['message'] ?? 'Unable to load leaderboard.');
    }
    return data;
  }

  Map<String, dynamic> _decode(String responseBody) {
    if (responseBody.isEmpty) {
      return <String, dynamic>{};
    }
    return jsonDecode(responseBody) as Map<String, dynamic>;
  }
}
