class ReferralHistory {
  final int id;
  final int userId;
  final String userName;
  final String userUsername;
  final DateTime referredAt;
  final bool rewardGiven;

  ReferralHistory({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userUsername,
    required this.referredAt,
    required this.rewardGiven,
  });

  factory ReferralHistory.fromJson(Map<String, dynamic> json) {
    return ReferralHistory(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      userName: json['user_name'] as String? ?? '',
      userUsername: json['user_username'] as String? ?? '',
      referredAt:
          DateTime.tryParse(json['referred_at'] as String? ?? '') ??
          DateTime.now(),
      rewardGiven: json['reward_given'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'user_name': userName,
    'user_username': userUsername,
    'referred_at': referredAt.toIso8601String(),
    'reward_given': rewardGiven,
  };
}
