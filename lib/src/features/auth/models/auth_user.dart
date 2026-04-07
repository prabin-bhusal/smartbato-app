class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.dateOfBirth,
    this.age,
    this.lastDegree,
    this.lastCollegeName,
    this.district,
    this.createdAt,
    this.username,
    required this.coins,
    required this.dataFilled,
    required this.roles,
    this.currentCourseId,
    this.currentCourseName,
    this.currentCourseSelectedAt,
    this.battleEntryFee = 10,
    this.battlePrizeCoin = 15,
    this.xp = 0,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final DateTime? dateOfBirth;
  final int? age;
  final String? lastDegree;
  final String? lastCollegeName;
  final String? district;
  final DateTime? createdAt;
  final String? username;
  final int coins;
  final bool dataFilled;
  final List<String> roles;
  final int? currentCourseId;
  final String? currentCourseName;
  final DateTime? currentCourseSelectedAt;
  final int battleEntryFee;
  final int battlePrizeCoin;
  final int xp;

  AuthUser copyWith({
    String? name,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    int? age,
    String? lastDegree,
    String? lastCollegeName,
    String? district,
    DateTime? createdAt,
    String? username,
    int? coins,
    bool? dataFilled,
    List<String>? roles,
    int? currentCourseId,
    String? currentCourseName,
    DateTime? currentCourseSelectedAt,
    int? battleEntryFee,
    int? battlePrizeCoin,
    int? xp,
  }) {
    return AuthUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      age: age ?? this.age,
      lastDegree: lastDegree ?? this.lastDegree,
      lastCollegeName: lastCollegeName ?? this.lastCollegeName,
      district: district ?? this.district,
      createdAt: createdAt ?? this.createdAt,
      username: username ?? this.username,
      coins: coins ?? this.coins,
      dataFilled: dataFilled ?? this.dataFilled,
      roles: roles ?? this.roles,
      currentCourseId: currentCourseId ?? this.currentCourseId,
      currentCourseName: currentCourseName ?? this.currentCourseName,
      currentCourseSelectedAt:
          currentCourseSelectedAt ?? this.currentCourseSelectedAt,
      battleEntryFee: battleEntryFee ?? this.battleEntryFee,
      battlePrizeCoin: battlePrizeCoin ?? this.battlePrizeCoin,
      xp: xp ?? this.xp,
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final gamification =
        json['gamification'] as Map<String, dynamic>? ?? const {};
    return AuthUser(
      id: (json['id'] ?? 0) as int,
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      phone: json['phone']?.toString(),
      dateOfBirth: json['date_of_birth'] == null
          ? null
          : DateTime.tryParse(json['date_of_birth'].toString()),
      age: (json['age'] as num?)?.toInt(),
      lastDegree: json['last_degree']?.toString(),
      lastCollegeName: json['last_college_name']?.toString(),
      district: json['district']?.toString(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      username: json['username']?.toString(),
      coins: (json['coins'] ?? 0) as int,
      dataFilled: (json['data_filled'] ?? false) as bool,
      roles: (json['roles'] as List<dynamic>? ?? <dynamic>[])
          .map((role) => role.toString())
          .toList(),
      currentCourseId: json['current_course_id'] as int?,
      currentCourseName: json['current_course_name'] as String?,
      currentCourseSelectedAt: json['current_course_selected_at'] == null
          ? null
          : DateTime.tryParse(json['current_course_selected_at'].toString()),
      battleEntryFee: (gamification['battle_entry_fee'] as num?)?.toInt() ?? 10,
      battlePrizeCoin:
          (gamification['battle_prize_coin'] as num?)?.toInt() ?? 15,
      xp: (json['total_xp'] as num?)?.toInt() ?? 0,
    );
  }
}
