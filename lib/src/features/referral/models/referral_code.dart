class ReferralCode {
  final String code;

  ReferralCode({required this.code});

  factory ReferralCode.fromJson(String code) {
    return ReferralCode(code: code);
  }

  Map<String, dynamic> toJson() => {'code': code};
}
