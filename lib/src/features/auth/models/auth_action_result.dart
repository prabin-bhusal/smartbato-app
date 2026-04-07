import 'auth_coin_reward.dart';
import 'auth_session.dart';

class AuthActionResult {
  const AuthActionResult({
    required this.session,
    this.coinReward,
  });

  final AuthSession session;
  final AuthCoinReward? coinReward;
}
