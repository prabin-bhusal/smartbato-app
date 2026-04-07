import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../../core/network/secure_http_client.dart';

import '../../../core/config/api_config.dart';
import '../models/mock_test_models.dart';

class MockTestApi {
  final http.Client _client = SecureHttpClient();

  Future<MockTestListResponse> fetchMockTests(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/mock-tests');
    final response = await _get(uri, token);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to load mock tests.').toString(),
      );
    }

    return MockTestListResponse.fromJson(data);
  }

  Future<MockTestBeginResponse> beginMockTest({
    required String token,
    required int modelSetId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/mock-tests/$modelSetId/begin',
    );
    final response = await _post(uri, token, const <String, dynamic>{});
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to start mock test.').toString(),
      );
    }

    return MockTestBeginResponse.fromJson(data);
  }

  Future<MockTestSubmitResponse> submitMockTest({
    required String token,
    required int sessionId,
    required Map<int, String> answers,
    required int timeTaken,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/mock-tests/sessions/$sessionId/submit',
    );

    final payload = {
      'time_taken': timeTaken,
      'answers': answers.map((key, value) => MapEntry(key.toString(), value)),
    };

    final response = await _post(uri, token, payload);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to submit mock test.').toString(),
      );
    }

    return MockTestSubmitResponse.fromJson(data);
  }

  Future<MockViolationResponse> sendViolation({
    required String token,
    required int sessionId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/mock-tests/sessions/$sessionId/violation',
    );
    final response = await _post(uri, token, const <String, dynamic>{});
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to record violation.').toString(),
      );
    }

    return MockViolationResponse.fromJson(data);
  }

  Future<MockTestReportEnvelope> fetchReport({
    required String token,
    required int modelSetId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/mock-tests/$modelSetId/report',
    );
    final response = await _get(uri, token);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception((data['message'] ?? 'Unable to load report.').toString());
    }

    return MockTestReportEnvelope.fromJson(data);
  }

  Future<List<int>> downloadReportPdf({
    required String token,
    required int modelSetId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/mock-tests/$modelSetId/report/download',
    );
    final response = await _get(uri, token);

    if (response.statusCode >= 400) {
      final data = _decode(response.body);
      throw Exception(
        (data['message'] ?? 'Unable to download report.').toString(),
      );
    }

    return response.bodyBytes;
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

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }

    return jsonDecode(body) as Map<String, dynamic>;
  }
}
