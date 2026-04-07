import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/secure_http_client.dart';
import '../models/daily_challenge_models.dart';

class DailyChallengeApi {
  final http.Client _client = SecureHttpClient();

  dynamic _decode(String body) => jsonDecode(body);

  Future<DailyChallengeStatus> fetchStatus(String token) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/daily-challenge/status',
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
      throw Exception(
        data['message'] ?? 'Unable to fetch daily challenge status.',
      );
    }

    return DailyChallengeStatus.fromJson(data as Map<String, dynamic>);
  }

  Future<DailyChallengeBeginResponse> begin(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/daily-challenge/begin');

    late final http.Response response;
    try {
      response = await _client.post(
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
      throw Exception(data['message'] ?? 'Unable to start daily challenge.');
    }

    return DailyChallengeBeginResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<DailyChallengeSubmitResponse> submit({
    required String token,
    required int attemptId,
    required Map<int, String> answers,
    required int timeTaken,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/daily-challenge/$attemptId/submit',
    );

    late final http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'time_taken': timeTaken,
          'answers': answers.map((key, value) => MapEntry('$key', value)),
        }),
      );
    } on SocketException {
      throw Exception(
        'Network required. Please check your internet connection.',
      );
    }

    final data = _decode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to submit daily challenge.');
    }

    return DailyChallengeSubmitResponse.fromJson(data as Map<String, dynamic>);
  }
}
