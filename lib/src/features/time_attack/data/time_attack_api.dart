import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/secure_http_client.dart';
import '../models/time_attack_models.dart';

class TimeAttackApi {
  final http.Client _client = SecureHttpClient();

  dynamic _decode(String body) => jsonDecode(body);

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<TimeAttackStatusResponse> fetchStatus(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/time-attack/status');

    late final http.Response response;
    try {
      response = await _client.get(uri, headers: _headers(token));
    } on SocketException {
      throw Exception(
        'Network required. Please check your internet connection.',
      );
    }

    final data = _decode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to load Time Attack status.');
    }

    return TimeAttackStatusResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<TimeAttackStartResponse> start(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/time-attack/start');

    late final http.Response response;
    try {
      response = await _client.post(uri, headers: _headers(token));
    } on SocketException {
      throw Exception(
        'Network required. Please check your internet connection.',
      );
    }

    final data = _decode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to start Time Attack.');
    }

    return TimeAttackStartResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<TimeAttackAnswerResponse> submitAnswer({
    required String token,
    required int sessionId,
    required int questionId,
    required String selectedOption,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/time-attack/$sessionId/answer',
    );

    late final http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: {..._headers(token), 'Content-Type': 'application/json'},
        body: jsonEncode({
          'question_id': questionId,
          'selected_option': selectedOption,
        }),
      );
    } on SocketException {
      throw Exception(
        'Network required. Please check your internet connection.',
      );
    }

    final data = _decode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(
        data['message'] ?? 'Unable to submit Time Attack answer.',
      );
    }

    return TimeAttackAnswerResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<TimeAttackFinishResponse> finish({
    required String token,
    required int sessionId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/time-attack/$sessionId/finish',
    );

    late final http.Response response;
    try {
      response = await _client.post(uri, headers: _headers(token));
    } on SocketException {
      throw Exception(
        'Network required. Please check your internet connection.',
      );
    }

    final data = _decode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to finish Time Attack.');
    }

    return TimeAttackFinishResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<TimeAttackLeaderboardResponse> fetchLeaderboard(
    String token, {
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/time-attack/leaderboard?limit=$limit',
    );

    late final http.Response response;
    try {
      response = await _client.get(uri, headers: _headers(token));
    } on SocketException {
      throw Exception(
        'Network required. Please check your internet connection.',
      );
    }

    final data = _decode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(
        data['message'] ?? 'Unable to load Time Attack leaderboard.',
      );
    }

    return TimeAttackLeaderboardResponse.fromJson(data as Map<String, dynamic>);
  }
}
