import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../../core/network/secure_http_client.dart';

import '../../../core/config/api_config.dart';

class BattleApi {
  final http.Client _client = SecureHttpClient();

  Future<Map<String, dynamic>> matchmake(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/battles/matchmake');
    final response = await _post(uri, token, const <String, dynamic>{});
    return _decodeOrThrow(response, 'Unable to start battle.');
  }

  Future<Map<String, dynamic>> fetchBattle({
    required String token,
    required int battleId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/battles/$battleId');
    final response = await _get(uri, token);
    return _decodeOrThrow(response, 'Unable to load battle.');
  }

  Future<Map<String, dynamic>> fetchActiveBattle(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/battles/active');
    final response = await _get(uri, token);
    return _decodeOrThrow(response, 'Unable to load active battle.');
  }

  Future<Map<String, dynamic>> submitBattle({
    required String token,
    required int battleId,
    required List<Map<String, dynamic>> answers,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/battles/$battleId/submit',
    );
    final response = await _post(uri, token, <String, dynamic>{
      'answers': answers,
    });
    return _decodeOrThrow(response, 'Unable to submit battle answers.');
  }

  Future<Map<String, dynamic>> sendHeartbeat({
    required String token,
    required int battleId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/battles/$battleId/heartbeat',
    );
    final response = await _post(uri, token, const <String, dynamic>{});
    return _decodeOrThrow(response, 'Unable to sync battle state.');
  }

  Future<Map<String, dynamic>> acceptAi(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/battles/accept-ai');
    final response = await _post(uri, token, const <String, dynamic>{});
    return _decodeOrThrow(response, 'Unable to accept AI battle.');
  }

  Future<Map<String, dynamic>> cancelQueue(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/battles/queue');
    final response = await _delete(uri, token);
    return _decodeOrThrow(response, 'Unable to cancel matchmaking.');
  }

  Future<Map<String, dynamic>> cancelInvite(String token) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/battles/invites/active',
    );
    final response = await _delete(uri, token);
    return _decodeOrThrow(response, 'Unable to cancel battle invite.');
  }

  Future<Map<String, dynamic>> createInvite({
    required String token,
    String? friendCode,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/battles/invites');
    final payload = <String, dynamic>{};
    if ((friendCode ?? '').trim().isNotEmpty) {
      payload['friend_code'] = friendCode!.trim();
    }
    final response = await _post(uri, token, payload);
    return _decodeOrThrow(response, 'Unable to create battle invite.');
  }

  Future<Map<String, dynamic>> fetchActiveInvite(String token) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/battles/invites/active',
    );
    final response = await _get(uri, token);
    return _decodeOrThrow(response, 'Unable to load active invite.');
  }

  Future<Map<String, dynamic>> joinInvite({
    required String token,
    required String code,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/battles/invites/join');
    final response = await _post(uri, token, <String, dynamic>{
      'code': code.trim(),
    });
    return _decodeOrThrow(response, 'Unable to join battle invite.');
  }

  Future<http.Response> _delete(Uri uri, String token) async {
    try {
      return await _client.delete(
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

  Map<String, dynamic> _decodeOrThrow(http.Response response, String fallback) {
    final data = _decode(response.body);
    if (response.statusCode >= 400) {
      throw Exception((data['message'] ?? fallback).toString());
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
