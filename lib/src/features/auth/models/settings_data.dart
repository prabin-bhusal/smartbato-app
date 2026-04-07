import 'profile_bootstrap.dart';

class SettingsData {
  const SettingsData({
    required this.userInfo,
    required this.categories,
    required this.additionalCourseCost,
  });

  final SettingsUserInfo userInfo;
  final List<ProfileCategory> categories;
  final int additionalCourseCost;

  factory SettingsData.fromJson(Map<String, dynamic> json) {
    return SettingsData(
      userInfo: SettingsUserInfo.fromJson(
        json['user'] as Map<String, dynamic>? ?? {},
      ),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((item) => ProfileCategory.fromJson(item as Map<String, dynamic>))
          .toList(),
      additionalCourseCost: (json['additional_course_cost'] as int?) ?? 500,
    );
  }
}

class SettingsUserInfo {
  const SettingsUserInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.coins,
    this.age,
    this.phone,
    this.dateOfBirth,
    this.lastDegree,
    this.lastCollegeName,
    this.district,
    this.currentCourseId,
    required this.selectedCategoryIds,
    required this.selectedCourseIds,
  });

  final int id;
  final String name;
  final String email;
  final int coins;
  final int? age;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? lastDegree;
  final String? lastCollegeName;
  final String? district;
  final int? currentCourseId;
  final List<int> selectedCategoryIds;
  final List<int> selectedCourseIds;

  factory SettingsUserInfo.fromJson(Map<String, dynamic> json) {
    return SettingsUserInfo(
      id: (json['id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      coins: (json['coins'] as int?) ?? 0,
      age: json['age'] as int?,
      phone: json['phone'] as String?,
      dateOfBirth: json['date_of_birth'] == null
          ? null
          : DateTime.tryParse(json['date_of_birth'].toString()),
      lastDegree: json['last_degree'] as String?,
      lastCollegeName: json['last_college_name'] as String?,
      district: json['district'] as String?,
      currentCourseId: json['current_course_id'] as int?,
      selectedCategoryIds:
          (json['selected_category_ids'] as List<dynamic>? ?? [])
              .map((e) => (e as num).toInt())
              .toList(),
      selectedCourseIds: (json['selected_course_ids'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }
}
