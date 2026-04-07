import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../../core/network/secure_http_client.dart';
import '../../../core/config/api_config.dart';
import '../models/referral_code.dart';
import '../models/referral_stats.dart';
import '../models/referral_history.dart';

class ReferralApi {
  final http.Client _client = SecureHttpClient();

  dynamic _decode(String body) => jsonDecode(body);

  /// Get user's referral code and stats
  Future<ReferralCode> getCode(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/referrals/code');

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
      throw Exception(data['message'] ?? 'Unable to fetch referral code.');
    }

    return ReferralCode.fromJson((data['code'] ?? '').toString());
  }

  /// Get referral stats
  Future<ReferralStats> getStats(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/referrals/stats');

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
      throw Exception(data['message'] ?? 'Unable to fetch referral stats.');
    }

    return ReferralStats.fromJson(data['stats'] as Map<String, dynamic>);
  }

  /// Get referral history (users referred by this user)
  Future<List<ReferralHistory>> getHistory(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/referrals/history');

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
      throw Exception(data['message'] ?? 'Unable to fetch referral history.');
    }

    final referrals = data['referrals'] as List<dynamic>? ?? [];
    return referrals
        .map((item) => ReferralHistory.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
