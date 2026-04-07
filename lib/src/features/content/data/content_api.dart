import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../../core/network/secure_http_client.dart';

import '../../../core/config/api_config.dart';
import '../models/content_models.dart';

class ContentApi {
  final http.Client _client = SecureHttpClient();

  Future<ContentListResponse> fetchBlogs({
    required String token,
    int page = 1,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/content/blogs?page=$page',
    );
    final response = await _get(uri, token);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception((data['message'] ?? 'Unable to load blogs.').toString());
    }

    return ContentListResponse.fromJson(data);
  }

  Future<ContentDetailResponse> fetchBlogDetail({
    required String token,
    required String slug,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/content/blogs/$slug');
    final response = await _get(uri, token);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception((data['message'] ?? 'Unable to load blog.').toString());
    }

    return ContentDetailResponse.fromJson(data);
  }

  Future<ContentListResponse> fetchNews({
    required String token,
    int page = 1,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/content/news?page=$page',
    );
    final response = await _get(uri, token);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception((data['message'] ?? 'Unable to load news.').toString());
    }

    return ContentListResponse.fromJson(data);
  }

  Future<ContentDetailResponse> fetchNewsDetail({
    required String token,
    required String slug,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/auth/content/news/$slug');
    final response = await _get(uri, token);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to load news detail.').toString(),
      );
    }

    return ContentDetailResponse.fromJson(data);
  }

  Future<NoticeListResponse> fetchNotices({
    required String token,
    int page = 1,
    int? categoryId,
    int? courseId,
  }) async {
    final params = <String, String>{
      'page': '$page',
      if (categoryId != null) 'category_id': '$categoryId',
      if (courseId != null) 'course_id': '$courseId',
    };

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/auth/content/notices',
    ).replace(queryParameters: params);
    final response = await _get(uri, token);
    final data = _decode(response.body);

    if (response.statusCode >= 400) {
      throw Exception(
        (data['message'] ?? 'Unable to load notices.').toString(),
      );
    }

    return NoticeListResponse.fromJson(data);
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

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }

    return jsonDecode(body) as Map<String, dynamic>;
  }
}
