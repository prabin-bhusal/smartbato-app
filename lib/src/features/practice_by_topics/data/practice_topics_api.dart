import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../../core/network/secure_http_client.dart';

import '../../../core/config/api_config.dart';
import '../models/practice_topics_models.dart';

class PracticeTopicsApi {
  final http.Client _client = SecureHttpClient();

  Future<PracticeTopicsMap> fetchMap(String token) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/practice-by-topics/map',
    );

    final response = await _get(uri, token);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to load topic map.').toString(),
      );
    }

    return PracticeTopicsMap.fromJson(data);
  }

  Future<String> unlockFeature(String token) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/practice-by-topics/unlock',
    );

    final response = await _post(uri, token, const <String, dynamic>{});
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to unlock practice by topics.').toString(),
      );
    }

    return (data['message'] ?? 'Unlocked successfully.').toString();
  }

  Future<String> unlockTopic({
    required String token,
    required int topicId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/practice-by-topics/$topicId/unlock',
    );

    final response = await _post(uri, token, const <String, dynamic>{});
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to unlock topic.').toString(),
      );
    }

    return (data['message'] ?? 'Unlocked successfully.').toString();
  }

  Future<PracticeTopicQuestion> fetchQuestion({
    required String token,
    required int topicId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/practice-by-topics/$topicId/question',
    );

    final response = await _get(uri, token);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to load question.').toString(),
      );
    }

    return PracticeTopicQuestion.fromJson(
      (data['question'] ?? <String, dynamic>{}) as Map<String, dynamic>,
    );
  }

  Future<PracticeTopicAnswerResult> submitAnswer({
    required String token,
    required int questionId,
    required String selectedOption,
    required int timeTaken,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/practice-by-topics/answer',
    );

    final response = await _post(uri, token, {
      'question_id': questionId,
      'selected_option': selectedOption,
      'time_taken': timeTaken,
    });

    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to submit answer.').toString(),
      );
    }

    return PracticeTopicAnswerResult.fromJson(data);
  }

  Future<String> fetchHint({
    required String token,
    required int questionId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/practice-by-topics/questions/$questionId/hint',
    );

    final response = await _get(uri, token);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception((data['message'] ?? 'Unable to load hint.').toString());
    }

    return (data['hint'] ?? '').toString();
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
