class AuthCoinReward {
  const AuthCoinReward({
    required this.amount,
    required this.reason,
    this.message,
  });

  final int amount;
  final String reason;
  final String? message;

  factory AuthCoinReward.fromJson(Map<String, dynamic> json) {
    return AuthCoinReward(
      amount: _asInt(json['amount']),
      reason: (json['reason'] ?? 'Coin reward').toString(),
      message: json['message']?.toString(),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
