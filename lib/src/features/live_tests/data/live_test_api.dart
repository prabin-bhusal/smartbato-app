import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../../core/network/secure_http_client.dart';

import '../../../core/config/api_config.dart';
import '../../mock_tests/models/mock_test_models.dart';

class LiveTestApi {
  LiveTestApi();
  final http.Client _client = SecureHttpClient();

  Future<LiveTestEnrollmentResponse> enrollLiveTest({
    required String token,
    required int liveTestId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/live-tests/$liveTestId/enroll',
    );
    final response = await _post(uri, token, const <String, dynamic>{});
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to enroll in live test.').toString(),
      );
    }

    return LiveTestEnrollmentResponse.fromJson(data);
  }

  Future<Set<int>> fetchEnrolledLiveTestIds(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/live-tests/enrolled');
    final response = await _get(uri, token);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to load enrolled live tests.').toString(),
      );
    }

    return (data['enrolled_live_test_ids'] as List<dynamic>? ?? <dynamic>[])
        .map(_asInt)
        .where((id) => id > 0)
        .toSet();
  }

  Future<Set<int>> fetchAttemptedLiveTestIds(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/live-tests/attempted');
    final response = await _get(uri, token);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to load attempted live tests.').toString(),
      );
    }

    return (data['attempted_live_test_ids'] as List<dynamic>? ?? <dynamic>[])
        .map(_asInt)
        .where((id) => id > 0)
        .toSet();
  }

  Future<MockTestBeginResponse> beginLiveTest({
    required String token,
    required int liveTestId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/live-tests/$liveTestId/begin',
    );
    final response = await _post(uri, token, const <String, dynamic>{});
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to start live test.').toString(),
      );
    }

    return MockTestBeginResponse.fromJson(data);
  }

  Future<MockTestSubmitResponse> submitLiveTest({
    required String token,
    required int sessionId,
    required Map<int, String> answers,
    required int timeTaken,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/live-tests/sessions/$sessionId/submit',
    );

    final payload = {
      'time_taken': timeTaken,
      'answers': answers.map((key, value) => MapEntry(key.toString(), value)),
    };

    final response = await _post(uri, token, payload);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to submit live test.').toString(),
      );
    }

    return MockTestSubmitResponse.fromJson(data);
  }

  Future<MockViolationResponse> sendViolation({
    required String token,
    required int sessionId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/live-tests/sessions/$sessionId/violation',
    );
    final response = await _post(uri, token, const <String, dynamic>{});
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to record live test violation.').toString(),
      );
    }

    return MockViolationResponse.fromJson(data);
  }

  Future<MockTestReportEnvelope> fetchReport({
    required String token,
    required int liveTestId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/live-tests/$liveTestId/report',
    );
    final response = await _get(uri, token);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to load live test report.').toString(),
      );
    }

    return MockTestReportEnvelope.fromJson(data);
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

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class LiveTestEnrollmentResponse {
  const LiveTestEnrollmentResponse({
    required this.message,
    required this.alreadyEnrolled,
    required this.enrollCost,
    required this.userCoins,
  });

  final String message;
  final bool alreadyEnrolled;
  final int enrollCost;
  final int userCoins;

  factory LiveTestEnrollmentResponse.fromJson(Map<String, dynamic> json) {
    return LiveTestEnrollmentResponse(
      message: (json['message'] ?? 'Enrollment complete.').toString(),
      alreadyEnrolled: (json['already_enrolled'] ?? false) as bool,
      enrollCost: _asIntStatic(json['enroll_cost']),
      userCoins: _asIntStatic(json['user_coins']),
    );
  }

  static int _asIntStatic(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
