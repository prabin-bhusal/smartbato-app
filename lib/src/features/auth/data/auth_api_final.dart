import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../../core/network/secure_http_client.dart';

import '../../../core/config/api_config.dart';
import '../models/auth_action_result.dart';
import '../models/auth_coin_reward.dart';
import '../models/auth_session.dart';
import '../models/auth_user.dart';
import '../models/profile_bootstrap.dart';
import '../models/settings_data.dart';
import '../../wallet/models/wallet_data.dart';

class AuthMeResult {
  const AuthMeResult({required this.user, this.coinReward});

  final AuthUser user;
  final AuthCoinReward? coinReward;
}

class AuthApi {
  final http.Client _client = SecureHttpClient();

  Future<AuthActionResult> login({
    required String email,
    required String password,
  }) async {
    return _authenticate(
      endpoint: '/v1/auth/login',
      expectedSuccessStatusCodes: const {200},
      unexpectedSuccessMessage: 'Invalid credentials.',
      payload: {
        'email': email,
        'password': password,
        'device_name': 'smartbato-mobile-app',
      },
    );
  }

  Future<AuthActionResult> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? referralCode,
  }) async {
    return _authenticate(
      endpoint: '/v1/auth/register',
      payload: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'device_name': 'smartbato-mobile-app',
        if (referralCode != null && referralCode.isNotEmpty)
          'referral_code': referralCode,
      },
    );
  }

  Future<AuthMeResult> me(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/me');

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
      throw Exception(data['message'] ?? 'Unable to fetch user profile.');
    }

    final rewardRaw = data['coin_reward'];
    final coinReward = rewardRaw is Map<String, dynamic>
        ? AuthCoinReward.fromJson(rewardRaw)
        : null;

    return AuthMeResult(
      user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
      coinReward: coinReward,
    );
  }

  Future<void> logout(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/logout');

    try {
      await _client.post(
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

  Future<ProfileBootstrap> profileBootstrap(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/profile-bootstrap');

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
      throw Exception(data['message'] ?? 'Unable to load profile options.');
    }

    return ProfileBootstrap.fromJson(data);
  }

  Future<List<String>> collegeSuggestions({
    required String token,
    required String query,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/college-suggestions',
    ).replace(queryParameters: {'q': query});

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
      throw Exception(data['message'] ?? 'Unable to load college suggestions.');
    }

    final items = data['items'] as List<dynamic>? ?? const [];
    return items.map((e) => e.toString()).toList();
  }

  Future<AuthUser> completeProfile({
    required String token,
    required String phone,
    required String dateOfBirth,
    required String lastDegree,
    required String lastCollegeName,
    required String district,
    required int categoryId,
    required int courseId,
    String? referralCode,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/complete-profile');

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
          'phone': phone,
          'date_of_birth': dateOfBirth,
          'last_degree': lastDegree,
          'last_college_name': lastCollegeName,
          'district': district,
          'category': categoryId,
          'course': courseId,
          if (referralCode != null && referralCode.isNotEmpty)
            'referral_code': referralCode,
        }),
      );
    } on SocketException {
      throw Exception(
        'Network required. Please check your internet connection.',
      );
    }

    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to complete profile.');
    }

    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<SettingsData> fetchSettings(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/settings');
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
      throw Exception(data['message'] ?? 'Unable to load settings.');
    }
    return SettingsData.fromJson(data);
  }

  Future<AuthUser> updateSettings({
    required String token,
    required List<int> categoryIds,
    required List<int> courseIds,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/settings');
    final payload = <String, dynamic>{
      'categories': categoryIds,
      'courses': courseIds,
    };
    late final http.Response response;
    try {
      response = await _client.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
    } on SocketException {
      throw Exception(
        'Network required. Please check your internet connection.',
      );
    }
    final data = _decode(response.body);
    if (response.statusCode >= 400) {
      final errors = data['errors'] as Map<String, dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        final first = (errors.values.first as List<dynamic>).first.toString();
        throw Exception(first);
      }
      throw Exception(data['message'] ?? 'Failed to update settings.');
    }
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AuthUser> setCurrentCourse({
    required String token,
    required int courseId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/settings/current-course',
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
        body: jsonEncode({'course_id': courseId}),
      );
    } on SocketException {
      throw Exception(
        'Network required. Please check your internet connection.',
      );
    }
    final data = _decode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Failed to set active course.');
    }
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AuthUser> updateProfile({
    required String token,
    required String name,
    String? phone,
    String? dateOfBirth,
    String? lastDegree,
    String? lastCollegeName,
    String? district,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/profile');
    late final http.Response response;
    try {
      response = await _client.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (dateOfBirth != null && dateOfBirth.isNotEmpty)
            'date_of_birth': dateOfBirth,
          if (lastDegree?.isNotEmpty ?? false) 'last_degree': lastDegree,
          if (lastCollegeName != null && lastCollegeName.isNotEmpty)
            'last_college_name': lastCollegeName,
          if (district?.isNotEmpty ?? false) 'district': district,
        }),
      );
    } on SocketException {
      throw Exception(
        'Network required. Please check your internet connection.',
      );
    }
    final data = _decode(response.body);
    if (response.statusCode >= 400) {
      final errors = data['errors'] as Map<String, dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        final first = (errors.values.first as List<dynamic>).first.toString();
        throw Exception(first);
      }
      throw Exception(data['message'] ?? 'Failed to update profile.');
    }
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> updatePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
    required String passwordConfirmation,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/password');
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
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': passwordConfirmation,
        }),
      );
    } on SocketException {
      throw Exception(
        'Network required. Please check your internet connection.',
      );
    }
    final data = _decode(response.body);
    if (response.statusCode >= 400) {
      final errors = data['errors'] as Map<String, dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        final first = (errors.values.first as List<dynamic>).first.toString();
        throw Exception(first);
      }
      throw Exception(data['message'] ?? 'Failed to change password.');
    }
  }

  Future<void> deleteProfile({
    required String token,
    required String currentPassword,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/profile');
    late final http.Response response;
    try {
      response = await _client.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'current_password': currentPassword}),
      );
    } on SocketException {
      throw Exception(
        'Network required. Please check your internet connection.',
      );
    }
    final data = _decode(response.body);
    if (response.statusCode >= 400) {
      final errors = data['errors'] as Map<String, dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        final first = (errors.values.first as List<dynamic>).first.toString();
        throw Exception(first);
      }
      throw Exception(data['message'] ?? 'Failed to delete account.');
    }
  }

  Future<WalletData> fetchWallet(String token, {int page = 1}) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/wallet',
    ).replace(queryParameters: {'page': page.toString()});
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
      throw Exception(data['message'] ?? 'Unable to load wallet.');
    }
    return WalletData.fromJson(data);
  }

  Future<AuthActionResult> _authenticate({
    required String endpoint,
    required Map<String, dynamic> payload,
    Set<int>? expectedSuccessStatusCodes,
    String? unexpectedSuccessMessage,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    late final http.Response response;

    try {
      response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );
    } on SocketException {
      throw Exception(
        'Network required. Please check your internet connection.',
      );
    }

    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Authentication failed.');
    }

    if (expectedSuccessStatusCodes != null &&
        !expectedSuccessStatusCodes.contains(response.statusCode)) {
      throw Exception(unexpectedSuccessMessage ?? 'Authentication failed.');
    }

    // Safely extract token and user data with proper null checking
    final tokenData = data['token'];
    if (tokenData is! Map<String, dynamic>) {
      throw Exception(
        'Invalid server response: missing or invalid token data.',
      );
    }

    final userData = data['user'];
    if (userData is! Map<String, dynamic>) {
      throw Exception('Invalid server response: missing or invalid user data.');
    }

    final accessToken = tokenData['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw Exception(
        'Invalid server response: missing or invalid access token.',
      );
    }

    final session = AuthSession(
      token: accessToken,
      expiresAt: DateTime.tryParse(tokenData['expires_at']?.toString() ?? ''),
      user: AuthUser.fromJson(userData),
    );

    final rewardRaw = data['coin_reward'];
    final coinReward = rewardRaw is Map<String, dynamic>
        ? AuthCoinReward.fromJson(rewardRaw)
        : null;

    return AuthActionResult(session: session, coinReward: coinReward);
  }

  Map<String, dynamic> _decode(String responseBody) {
    if (responseBody.isEmpty) {
      return <String, dynamic>{};
    }

    return jsonDecode(responseBody) as Map<String, dynamic>;
  }
}
