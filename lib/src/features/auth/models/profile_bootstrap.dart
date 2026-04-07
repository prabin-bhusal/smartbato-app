class ProfileBootstrap {
  const ProfileBootstrap({
    required this.categories,
  });

  final List<ProfileCategory> categories;

  factory ProfileBootstrap.fromJson(Map<String, dynamic> json) {
    return ProfileBootstrap(
      categories: (json['categories'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => ProfileCategory.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProfileCategory {
  const ProfileCategory({
    required this.id,
    required this.name,
    required this.courses,
  });

  final int id;
  final String name;
  final List<ProfileCourse> courses;

  factory ProfileCategory.fromJson(Map<String, dynamic> json) {
    return ProfileCategory(
      id: (json['id'] ?? 0) as int,
      name: (json['name'] ?? '') as String,
      courses: (json['courses'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => ProfileCourse.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProfileCourse {
  const ProfileCourse({
    required this.id,
    required this.name,
    required this.categoryId,
  });

  final int id;
  final String name;
  final int categoryId;

  factory ProfileCourse.fromJson(Map<String, dynamic> json) {
    return ProfileCourse(
      id: (json['id'] ?? 0) as int,
      name: (json['name'] ?? '') as String,
      categoryId: (json['category_id'] ?? 0) as int,
    );
  }
}
