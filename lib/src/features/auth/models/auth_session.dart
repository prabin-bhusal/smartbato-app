import 'auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.expiresAt,
    required this.user,
  });

  final String token;
  final DateTime? expiresAt;
  final AuthUser user;

  factory AuthSession.fromStorage(Map<String, Object?> raw) {
    return AuthSession(
      token: raw['token'] as String,
      expiresAt: raw['expires_at'] == null
          ? null
          : DateTime.tryParse(raw['expires_at'] as String),
      user: AuthUser(
        id: raw['user_id'] as int,
        name: raw['user_name'] as String,
        email: raw['user_email'] as String,
        phone: raw['user_phone'] as String?,
        dateOfBirth: raw['user_dob'] == null
            ? null
            : DateTime.tryParse(raw['user_dob'] as String),
        lastDegree: raw['user_last_degree'] as String?,
        lastCollegeName: raw['user_last_college_name'] as String?,
        district: raw['user_district'] as String?,
        createdAt: raw['user_created_at'] == null
            ? null
            : DateTime.tryParse(raw['user_created_at'] as String),
        username: raw['user_username'] as String?,
        coins: raw['user_coins'] as int,
        dataFilled: raw['user_data_filled'] as bool,
        roles: (raw['user_roles'] as String)
            .split(',')
            .where((role) => role.isNotEmpty)
            .toList(),
        currentCourseId: raw['user_course_id'] as int?,
        currentCourseName: raw['user_course_name'] as String?,
        currentCourseSelectedAt: raw['user_course_selected_at'] == null
            ? null
            : DateTime.tryParse(raw['user_course_selected_at'] as String),
      ),
    );
  }
}
