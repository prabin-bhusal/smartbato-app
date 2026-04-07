import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../../core/network/secure_http_client.dart';

import '../../../core/config/api_config.dart';

class DiscussionApi {
  final http.Client _client = SecureHttpClient();

  Future<Map<String, dynamic>> fetchMessages({
    required String token,
    required int courseId,
    int? beforeId,
    int limit = 20,
  }) async {
    final uri =
        Uri.parse(
          '${ApiConfig.baseUrl}/v1/auth/discussion/courses/$courseId/messages',
        ).replace(
          queryParameters: {
            'limit': limit.toString(),
            if (beforeId != null && beforeId > 0)
              'before_id': beforeId.toString(),
          },
        );
    final response = await _get(uri, token);
    return _decodeOrThrow(response, 'Unable to load discussion messages.');
  }

  Future<Map<String, dynamic>> fetchReplies({
    required String token,
    required int messageId,
    int? beforeReplyId,
    int limit = 10,
  }) async {
    final uri =
        Uri.parse(
          '${ApiConfig.baseUrl}/v1/auth/discussion/messages/$messageId/replies',
        ).replace(
          queryParameters: {
            'limit': limit.toString(),
            if (beforeReplyId != null && beforeReplyId > 0)
              'before_reply_id': beforeReplyId.toString(),
          },
        );
    final response = await _get(uri, token);
    return _decodeOrThrow(response, 'Unable to load older replies.');
  }

  Future<Map<String, dynamic>> postMessage({
    required String token,
    required int courseId,
    required String body,
    int? parentMessageId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/discussion/courses/$courseId/messages',
    );
    final payload = <String, dynamic>{'body': body};
    if (parentMessageId != null) {
      payload['parent_message_id'] = parentMessageId;
    }
    final response = await _post(uri, token, payload);
    return _decodeOrThrow(response, 'Unable to send discussion message.');
  }

  Future<Map<String, dynamic>> createPoll({
    required String token,
    required int courseId,
    required String question,
    required List<String> options,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/discussion/courses/$courseId/polls',
    );
    final response = await _post(uri, token, {
      'question': question,
      'options': options,
    });
    return _decodeOrThrow(response, 'Unable to create poll.');
  }

  Future<Map<String, dynamic>> votePoll({
    required String token,
    required int messageId,
    required int optionId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/discussion/messages/$messageId/poll-vote',
    );
    final response = await _post(uri, token, {'option_id': optionId});
    return _decodeOrThrow(response, 'Unable to submit poll vote.');
  }

  Future<Map<String, dynamic>> toggleLike({
    required String token,
    required int messageId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/discussion/messages/$messageId/like',
    );
    final response = await _post(uri, token, <String, dynamic>{});
    return _decodeOrThrow(response, 'Unable to like message.');
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
