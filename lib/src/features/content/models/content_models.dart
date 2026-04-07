class PagedMeta {
  const PagedMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.hasMorePages,
  });

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final bool hasMorePages;

  factory PagedMeta.fromJson(Map<String, dynamic> json) {
    return PagedMeta(
      currentPage: _asInt(json['current_page']),
      lastPage: _asInt(json['last_page']),
      perPage: _asInt(json['per_page']),
      total: _asInt(json['total']),
      hasMorePages: (json['has_more_pages'] ?? false) as bool,
    );
  }
}

class ContentListItem {
  const ContentListItem({
    required this.title,
    required this.slug,
    required this.excerpt,
    required this.thumbnailUrl,
    required this.publishedAt,
  });

  final String title;
  final String slug;
  final String excerpt;
  final String? thumbnailUrl;
  final DateTime? publishedAt;

  factory ContentListItem.fromJson(Map<String, dynamic> json) {
    return ContentListItem(
      title: (json['title'] ?? '-') as String,
      slug: (json['slug'] ?? '') as String,
      excerpt: (json['excerpt'] ?? json['summary'] ?? '') as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      publishedAt: _asDate(json['published_at'] ?? json['created_at']),
    );
  }
}

class ContentListResponse {
  const ContentListResponse({
    required this.items,
    required this.meta,
  });

  final List<ContentListItem> items;
  final PagedMeta meta;

  factory ContentListResponse.fromJson(Map<String, dynamic> json) {
    return ContentListResponse(
      items: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => ContentListItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      meta: PagedMeta.fromJson((json['meta'] ?? const <String, dynamic>{}) as Map<String, dynamic>),
    );
  }
}

class ContentDetail {
  const ContentDetail({
    required this.title,
    required this.slug,
    required this.excerpt,
    required this.contentHtml,
    required this.thumbnailUrl,
    required this.publishedAt,
  });

  final String title;
  final String slug;
  final String excerpt;
  final String contentHtml;
  final String? thumbnailUrl;
  final DateTime? publishedAt;

  factory ContentDetail.fromJson(Map<String, dynamic> json) {
    return ContentDetail(
      title: (json['title'] ?? '-') as String,
      slug: (json['slug'] ?? '') as String,
      excerpt: (json['excerpt'] ?? json['summary'] ?? '') as String,
      contentHtml: (json['content_html'] ?? '') as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      publishedAt: _asDate(json['published_at'] ?? json['created_at']),
    );
  }
}

class ContentDetailResponse {
  const ContentDetailResponse({
    required this.item,
    required this.related,
  });

  final ContentDetail item;
  final List<ContentListItem> related;

  factory ContentDetailResponse.fromJson(Map<String, dynamic> json) {
    return ContentDetailResponse(
      item: ContentDetail.fromJson((json['item'] ?? const <String, dynamic>{}) as Map<String, dynamic>),
      related: (json['related'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => ContentListItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class NoticeFilterOption {
  const NoticeFilterOption({
    required this.id,
    required this.name,
    this.categoryId,
  });

  final int id;
  final String name;
  final int? categoryId;

  factory NoticeFilterOption.fromJson(Map<String, dynamic> json) {
    return NoticeFilterOption(
      id: _asInt(json['id']),
      name: (json['name'] ?? '-') as String,
      categoryId: json['category_id'] == null ? null : _asInt(json['category_id']),
    );
  }
}

class NoticeItem {
  const NoticeItem({
    required this.id,
    required this.slug,
    required this.title,
    required this.contentHtml,
    required this.contentPreview,
    required this.thumbnailUrl,
    required this.publishedAt,
    required this.categoryName,
    required this.courseName,
    required this.attachmentName,
    required this.attachmentUrl,
  });

  final int id;
  final String slug;
  final String title;
  final String contentHtml;
  final String contentPreview;
  final String? thumbnailUrl;
  final DateTime? publishedAt;
  final String? categoryName;
  final String? courseName;
  final String? attachmentName;
  final String? attachmentUrl;

  factory NoticeItem.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    final course = json['course'] as Map<String, dynamic>?;

    return NoticeItem(
      id: _asInt(json['id']),
      slug: (json['slug'] ?? '') as String,
      title: (json['title'] ?? '-') as String,
      contentHtml: (json['content_html'] ?? '') as String,
      contentPreview: (json['content_preview'] ?? '') as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      publishedAt: _asDate(json['published_at'] ?? json['created_at']),
      categoryName: category == null ? null : category['name'] as String?,
      courseName: course == null ? null : course['name'] as String?,
      attachmentName: json['attachment_name'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
    );
  }
}

class NoticeFilters {
  const NoticeFilters({
    required this.selectedCategoryId,
    required this.selectedCourseId,
    required this.categories,
    required this.courses,
  });

  final int? selectedCategoryId;
  final int? selectedCourseId;
  final List<NoticeFilterOption> categories;
  final List<NoticeFilterOption> courses;

  factory NoticeFilters.fromJson(Map<String, dynamic> json) {
    return NoticeFilters(
      selectedCategoryId: json['selected_category_id'] == null ? null : _asInt(json['selected_category_id']),
      selectedCourseId: json['selected_course_id'] == null ? null : _asInt(json['selected_course_id']),
      categories: (json['categories'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => NoticeFilterOption.fromJson(item as Map<String, dynamic>))
          .toList(),
      courses: (json['courses'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => NoticeFilterOption.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class NoticeListResponse {
  const NoticeListResponse({
    required this.items,
    required this.meta,
    required this.filters,
  });

  final List<NoticeItem> items;
  final PagedMeta meta;
  final NoticeFilters filters;

  factory NoticeListResponse.fromJson(Map<String, dynamic> json) {
    return NoticeListResponse(
      items: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => NoticeItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      meta: PagedMeta.fromJson((json['meta'] ?? const <String, dynamic>{}) as Map<String, dynamic>),
      filters: NoticeFilters.fromJson((json['filters'] ?? const <String, dynamic>{}) as Map<String, dynamic>),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _asDate(Object? value) {
  if (value is String) return DateTime.tryParse(value);
  return null;
}
