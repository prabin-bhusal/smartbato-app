import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/auth_controller.dart';
import '../../../core/theme/app_page_shell.dart';
import '../../../core/theme/app_snackbar.dart';
import '../models/wallet_data.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ScrollController _txScrollController;

  bool _loading = true;
  String? _error;
  WalletData? _wallet;
  int _selectedPackageIndex = 0;
  final List<WalletTransaction> _transactions = <WalletTransaction>[];
  WalletMeta? _txMeta;
  int _txCurrentPage = 1;
  bool _txLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _txScrollController = ScrollController()..addListener(_onTxScroll);
    _loadWallet();
  }

  @override
  void dispose() {
    _txScrollController.removeListener(_onTxScroll);
    _txScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTxScroll() {
    if (!_txScrollController.hasClients || _txLoadingMore || _loading) {
      return;
    }

    final position = _txScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMoreTransactions();
    }
  }

  Future<void> _loadWallet() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final wallet = await widget.authController.loadWallet(page: 1);
      if (!mounted) {
        return;
      }
      setState(() {
        _wallet = wallet;
        _selectedPackageIndex = 0;
        _transactions
          ..clear()
          ..addAll(wallet.transactions);
        _txMeta = wallet.meta;
        _txCurrentPage = wallet.meta.currentPage;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMoreTransactions() async {
    final wallet = _wallet;
    final meta = _txMeta;
    if (wallet == null || meta == null || !meta.hasMorePages) {
      return;
    }

    if (_txLoadingMore) {
      return;
    }

    setState(() {
      _txLoadingMore = true;
    });

    try {
      final nextPage = _txCurrentPage + 1;
      final nextWallet = await widget.authController.loadWallet(page: nextPage);
      if (!mounted) {
        return;
      }

      setState(() {
        _wallet = nextWallet;
        _transactions.addAll(nextWallet.transactions);
        _txMeta = nextWallet.meta;
        _txCurrentPage = nextWallet.meta.currentPage;
      });
    } catch (_) {
      // Keep existing list when next-page fetch fails.
    } finally {
      if (mounted) {
        setState(() {
          _txLoadingMore = false;
        });
      }
    }
  }

  Future<void> _openWhatsapp() async {
    final wallet = _wallet;
    if (wallet == null || wallet.topup.packages.isEmpty) {
      return;
    }

    final selected = wallet.topup.packages[_selectedPackageIndex];
    final base = wallet.topup.whatsappLink;
    final message =
        'Hello, I want to top up ${selected.totalCoins} coins package (${selected.price.toStringAsFixed(0)} NPR). Please share payment details.';
    final uri = Uri.parse('$base?text=${Uri.encodeComponent(message)}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      AppSnackbar.error(context, 'Unable to open WhatsApp.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppPageShell(
        maxWidth: 920,
        children: [
          AppHeroBanner(
            title: 'Wallet',
            subtitle:
                'Loading your balance, top-up packages, and transactions.',
            icon: Icons.account_balance_wallet_rounded,
            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          ),
          SizedBox(height: 14),
          AppSurfaceCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return AppPageShell(
        maxWidth: 920,
        children: [
          const AppHeroBanner(
            title: 'Wallet',
            subtitle: 'We could not load your wallet details right now.',
            icon: Icons.account_balance_wallet_rounded,
            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          ),
          const SizedBox(height: 14),
          AppSurfaceCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadWallet,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final wallet = _wallet!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Balance banner ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _BalanceBanner(balance: wallet.balance),
        ),

        // ── Pill Tab Bar ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF475569),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: const Color(0xFF1D4ED8),
                borderRadius: BorderRadius.circular(9),
              ),
              dividerColor: Colors.transparent,
              splashBorderRadius: BorderRadius.circular(9),
              tabs: const [
                Tab(text: '💰  Top Up'),
                Tab(text: '🪙  Transactions'),
              ],
            ),
          ),
        ),

        // ── Tab Views ──────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TopUpTab(
                wallet: wallet,
                selectedIndex: _selectedPackageIndex,
                onSelect: (i) => setState(() => _selectedPackageIndex = i),
                onWhatsapp: _openWhatsapp,
                onRefresh: _loadWallet,
              ),
              _TransactionsTab(
                wallet: wallet,
                transactions: _transactions,
                hasMorePages: _txMeta?.hasMorePages ?? false,
                loadingMore: _txLoadingMore,
                scrollController: _txScrollController,
                onRefresh: _loadWallet,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Top Up Tab ───────────────────────────────────────────────────────────────

class _TopUpTab extends StatelessWidget {
  const _TopUpTab({
    required this.wallet,
    required this.selectedIndex,
    required this.onSelect,
    required this.onWhatsapp,
    required this.onRefresh,
  });

  final WalletData wallet;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onWhatsapp;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  'Select Top-up Amount',
                  'Choose a package and chat with our team on WhatsApp to complete payment.',
                ),
                const SizedBox(height: 16),

                // Package cards
                ...wallet.topup.packages.asMap().entries.map((entry) {
                  final i = entry.key;
                  final pkg = entry.value;
                  final selected = i == selectedIndex;
                  return GestureDetector(
                    onTap: () => onSelect(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFF0FDF4)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFE2E8F0),
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: selected
                            ? [
                                const BoxShadow(
                                  color: Color(0x1A22C55E),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.monetization_on_rounded,
                            color: Color(0xFFF59E0B),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${pkg.totalCoins} Coins',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (pkg.bonus > 0)
                                  Text(
                                    '+${pkg.bonus} bonus coins!',
                                    style: const TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${pkg.price.toStringAsFixed(0)} NPR',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${wallet.topup.nprPerCoin.toStringAsFixed(2)} NPR/coin',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: selected
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFCBD5E1),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 4),

                // WhatsApp info box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.chat_rounded,
                            color: Color(0xFF16A34A),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Manual Payment via WhatsApp',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF14532D),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _BulletText(
                        'Conversion: ${wallet.topup.nprPerCoin.toStringAsFixed(2)} NPR = ${wallet.topup.coinPerNpr.toStringAsFixed(2)} Coin',
                      ),
                      const _BulletText(
                        'Select package and tap "Chat on WhatsApp"',
                      ),
                      const _BulletText(
                        'Our team will share payment details in chat',
                      ),
                      const _BulletText(
                        'After payment verification, coins will be added manually',
                      ),
                      _BulletText('WhatsApp: ${wallet.topup.whatsappNumber}'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onWhatsapp,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Chat on WhatsApp'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.headset_mic_rounded,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manual Top-up Support',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Payment and coin credit are handled manually by support through WhatsApp chat confirmation.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(padding: const EdgeInsets.all(16), child: child);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
      ],
    );
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF16A34A))),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF166534), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Transactions Tab ─────────────────────────────────────────────────────────

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab({
    required this.wallet,
    required this.transactions,
    required this.hasMorePages,
    required this.loadingMore,
    required this.scrollController,
    required this.onRefresh,
  });

  final WalletData wallet;
  final List<WalletTransaction> transactions;
  final bool hasMorePages;
  final bool loadingMore;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.swap_horiz_rounded,
                  color: Color(0xFF1D4ED8),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${wallet.topup.nprPerCoin.toStringAsFixed(2)} NPR = ${wallet.topup.coinPerNpr.toStringAsFixed(2)} coin',
                    style: const TextStyle(
                      color: Color(0xFF1E40AF),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: Color(0xFFF59E0B),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${wallet.balance} coins',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A8A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (transactions.isEmpty)
            AppSurfaceCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Color(0xFF94A3B8),
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No transactions yet',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your coin history will appear here.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ...transactions.map(
              (tx) => _TxCard(tx: tx, formatDate: _formatDate),
            ),
          if (loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (!hasMorePages && transactions.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'No more transactions',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = value.hour == 0
        ? 12
        : (value.hour > 12 ? value.hour - 12 : value.hour);
    final m = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '${months[value.month - 1]} ${value.day}, ${value.year}  $h:$m $suffix';
  }
}

// ─── Transaction card ─────────────────────────────────────────────────────────

class _TxCard extends StatelessWidget {
  const _TxCard({required this.tx, required this.formatDate});

  final WalletTransaction tx;
  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    final amountColor = isCredit
        ? const Color(0xFF059669)
        : const Color(0xFFDC2626);
    final iconBg = isCredit ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    final iconColor = isCredit
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);
    final typeLabel =
        tx.type.substring(0, 1).toUpperCase() + tx.type.substring(1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppSurfaceCard(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(
                isCredit
                    ? Icons.add_circle_outline_rounded
                    : Icons.remove_circle_outline_rounded,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.sourceLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: iconColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          formatDate(tx.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${isCredit ? '+' : ''}${tx.amount}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Premium Balance Banner ───────────────────────────────────────────────────

class _BalanceBanner extends StatelessWidget {
  const _BalanceBanner({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      colors: [Color(0xFFFEF9C3), Color(0xFFFDE68A)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                        blurRadius: 18,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.monetization_on_rounded,
                    color: Color(0xFFB45309),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YOUR BALANCE',
                        style: TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$balance',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'coins',
                            style: TextStyle(
                              color: Color(0xFFBFDBFE),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Wallet',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
