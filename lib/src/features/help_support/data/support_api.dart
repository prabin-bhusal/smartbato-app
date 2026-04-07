import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../../core/network/secure_http_client.dart';

import '../../../core/config/api_config.dart';

class SupportApi {
  final http.Client _client = SecureHttpClient();

  Future<Map<String, dynamic>> fetchThreads(
    String token, {
    int page = 1,
    int perPage = 20,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/support/threads',
    ).replace(queryParameters: {'page': '$page', 'per_page': '$perPage'});
    final response = await _get(uri, token);
    return _decodeOrThrow(response, 'Unable to load support threads.');
  }

  Future<Map<String, dynamic>> openThread({
    required String token,
    required String message,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/support/threads');
    final response = await _post(uri, token, {'message': message});
    return _decodeOrThrow(response, 'Unable to create support thread.');
  }

  Future<Map<String, dynamic>> fetchThreadMessages({
    required String token,
    required int threadId,
    int? beforeId,
    int limit = 20,
  }) async {
    final uri =
        Uri.parse(
          '${ApiConfig.baseUrl}/v1/auth/support/threads/$threadId',
        ).replace(
          queryParameters: {
            'limit': '$limit',
            if (beforeId != null && beforeId > 0) 'before_id': '$beforeId',
          },
        );
    final response = await _get(uri, token);
    return _decodeOrThrow(response, 'Unable to load support messages.');
  }

  Future<Map<String, dynamic>> sendMessage({
    required String token,
    required int threadId,
    required String message,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/support/threads/$threadId/messages',
    );
    final response = await _post(uri, token, {'message': message});
    return _decodeOrThrow(response, 'Unable to send support message.');
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
