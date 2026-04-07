class WalletData {
  const WalletData({
    required this.balance,
    required this.topup,
    required this.transactions,
    required this.meta,
  });

  final int balance;
  final WalletTopupInfo topup;
  final List<WalletTransaction> transactions;
  final WalletMeta meta;

  factory WalletData.fromJson(Map<String, dynamic> json) {
    return WalletData(
      balance: (json['balance'] ?? 0) as int,
      topup: WalletTopupInfo.fromJson(
        (json['topup'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      ),
      transactions: (json['transactions'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (item) => WalletTransaction.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      meta: WalletMeta.fromJson(
        (json['meta'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      ),
    );
  }
}

class WalletTopupInfo {
  const WalletTopupInfo({
    required this.nprPerCoin,
    required this.coinPerNpr,
    required this.whatsappNumber,
    required this.whatsappLink,
    required this.packages,
  });

  final double nprPerCoin;
  final double coinPerNpr;
  final String whatsappNumber;
  final String whatsappLink;
  final List<WalletTopupPackage> packages;

  factory WalletTopupInfo.fromJson(Map<String, dynamic> json) {
    return WalletTopupInfo(
      nprPerCoin: (json['npr_per_coin'] ?? 1).toDouble(),
      coinPerNpr: (json['coin_per_npr'] ?? 1).toDouble(),
      whatsappNumber: (json['whatsapp_number'] ?? '') as String,
      whatsappLink: (json['whatsapp_link'] ?? '') as String,
      packages: (json['packages'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (item) => WalletTopupPackage.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class WalletTopupPackage {
  const WalletTopupPackage({
    required this.coins,
    required this.bonus,
    required this.totalCoins,
    required this.price,
  });

  final int coins;
  final int bonus;
  final int totalCoins;
  final double price;

  factory WalletTopupPackage.fromJson(Map<String, dynamic> json) {
    return WalletTopupPackage(
      coins: (json['coins'] ?? 0) as int,
      bonus: (json['bonus'] ?? 0) as int,
      totalCoins: (json['total_coins'] ?? 0) as int,
      price: (json['price'] ?? 0).toDouble(),
    );
  }
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.createdAt,
    required this.source,
    required this.sourceLabel,
    required this.type,
    required this.amount,
    required this.isCredit,
  });

  final int id;
  final DateTime? createdAt;
  final String source;
  final String sourceLabel;
  final String type;
  final int amount;
  final bool isCredit;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: (json['id'] ?? 0) as int,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
      source: (json['source'] ?? '') as String,
      sourceLabel: (json['source_label'] ?? '') as String,
      type: (json['type'] ?? '') as String,
      amount: (json['amount'] ?? 0) as int,
      isCredit: (json['is_credit'] ?? false) as bool,
    );
  }
}

class WalletMeta {
  const WalletMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.hasMorePages,
  });

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final bool hasMorePages;

  factory WalletMeta.fromJson(Map<String, dynamic> json) {
    return WalletMeta(
      currentPage: (json['current_page'] ?? 1) as int,
      lastPage: (json['last_page'] ?? 1) as int,
      perPage: (json['per_page'] ?? 20) as int,
      total: (json['total'] ?? 0) as int,
      hasMorePages: (json['has_more_pages'] ?? false) as bool,
    );
  }
}
