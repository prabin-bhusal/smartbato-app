class CoinGainEvent {
  const CoinGainEvent({
    required this.id,
    required this.amount,
    required this.reason,
    this.message,
  });

  final int id;
  final int amount;
  final String reason;
  final String? message;
}
