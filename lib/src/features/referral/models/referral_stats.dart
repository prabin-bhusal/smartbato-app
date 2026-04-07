class ReferralStats {
  final String? code;
  final int referredCount;
  final int coinsEarned;
  final int maxReferrals;
  final bool canReferMore;

  ReferralStats({
    this.code,
    required this.referredCount,
    required this.coinsEarned,
    required this.maxReferrals,
    required this.canReferMore,
  });

  factory ReferralStats.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    bool parseBool(dynamic value, {bool fallback = true}) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return fallback;
    }

    return ReferralStats(
      code: json['code']?.toString(),
      referredCount: parseInt(json['referred_count']),
      coinsEarned: parseInt(json['coins_earned']),
      maxReferrals: parseInt(json['max_referrals'], fallback: 10),
      canReferMore: parseBool(json['can_refer_more']),
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'referred_count': referredCount,
    'coins_earned': coinsEarned,
    'max_referrals': maxReferrals,
    'can_refer_more': canReferMore,
  };
}
