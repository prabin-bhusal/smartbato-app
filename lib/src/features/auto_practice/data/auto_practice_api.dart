import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../../core/network/secure_http_client.dart';

import '../../../core/config/api_config.dart';
import '../models/auto_practice_models.dart';

class AutoPracticeApi {
  final http.Client _client = SecureHttpClient();

  Future<AutoPracticeConfig> fetchConfig(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/auto-practice/config');
    final response = await _get(uri, token);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to load Auto Practice.').toString(),
      );
    }

    return AutoPracticeConfig.fromJson(data);
  }

  Future<String> unlockFeature(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/auto-practice/unlock');
    final response = await _post(uri, token, const <String, dynamic>{});
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to unlock Auto Practice.').toString(),
      );
    }

    return (data['message'] ?? 'Unlocked successfully.').toString();
  }

  Future<AutoPracticeSessionStart> startSession({
    required String token,
    required List<int> subjectIds,
    required List<int> topicIds,
    required String difficulty,
    required int questionCount,
    required String practiceMode,
    required String practiceStyle,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/auto-practice/sessions',
    );
    final response = await _post(uri, token, {
      'subject_ids': subjectIds,
      'topic_ids': topicIds,
      'difficulty': difficulty,
      'question_count': questionCount,
      'practice_mode': practiceMode,
      'practice_style': practiceStyle,
    });
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to start Auto Practice.').toString(),
      );
    }

    return AutoPracticeSessionStart.fromJson(data);
  }

  Future<AutoPracticeBatch> fetchBatch({
    required String token,
    required String sessionId,
    required int offset,
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/auto-practice/sessions/$sessionId/batch?offset=$offset&limit=$limit',
    );
    final response = await _get(uri, token);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to load more questions.').toString(),
      );
    }

    return AutoPracticeBatch.fromJson(
      data['batch'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  Future<http.Response> _get(Uri uri, String token) async {
    try {
      return await _client.get(
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
  }

  Future<http.Response> _post(
    Uri uri,
    String token,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
    } on SocketException {
      throw Exception(
        'Network required. Please check your internet connection.',
      );
    }
  }

  Map<String, dynamic> _decode(String responseBody) {
    if (responseBody.isEmpty) {
      return <String, dynamic>{};
    }

    return jsonDecode(responseBody) as Map<String, dynamic>;
  }
}
