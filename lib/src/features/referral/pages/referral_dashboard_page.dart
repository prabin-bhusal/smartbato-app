import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../data/referral_api.dart';
import '../models/index.dart';

class ReferralDashboardPage extends StatefulWidget {
  final String token;

  const ReferralDashboardPage({Key? key, required this.token})
    : super(key: key);

  @override
  State<ReferralDashboardPage> createState() => _ReferralDashboardPageState();
}

class _ReferralDashboardPageState extends State<ReferralDashboardPage> {
  late ReferralApi _api;
  late Future<void> _loadDataFuture;

  ReferralStats? _stats;
  List<ReferralHistory> _history = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = ReferralApi();
    _loadDataFuture = _loadData();
  }

  Future<void> _loadData() async {
    try {
      final codeTask = _api
          .getCode(widget.token)
          .catchError((_) => ReferralCode(code: ''));
      final statsTask = _api.getStats(widget.token);
      final historyTask = _api
          .getHistory(widget.token)
          .catchError((_) => <ReferralHistory>[]);

      final stats = await statsTask;
      final code = await codeTask;
      final history = await historyTask;
      final effectiveCode =
          (stats.code != null && stats.code!.trim().isNotEmpty)
          ? stats.code!
          : code.code;

      setState(() {
        _stats = ReferralStats(
          code: effectiveCode,
          referredCount: stats.referredCount,
          coinsEarned: stats.coinsEarned,
          maxReferrals: stats.maxReferrals,
          canReferMore: stats.canReferMore,
        );
        _history = history;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _shareReferralCode() {
    if (_stats?.code == null) return;

    final message =
        'Join SmartBato with my referral code: ${_stats!.code}\n'
        'Both of us will earn 20 coins! 🎁\n'
        'Download now!';

    Share.share(message, subject: 'SmartBato Referral Code');
  }

  void _copyReferralCode() {
    if (_stats?.code == null) return;

    Clipboard.setData(ClipboardData(text: _stats!.code!));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Referral code copied: ${_stats!.code}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Referral Program'), elevation: 0),
      body: FutureBuilder<void>(
        future: _loadDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading referral data',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _error ?? 'Unknown error',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _loadDataFuture = _loadData();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _loadData(),
            child: ListView(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite your friends',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'and earn coins together!',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Stats Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _buildStatCard(
                        title: 'Your Code',
                        value: _stats?.code ?? 'N/A',
                        icon: Icons.qr_code_2,
                        color: Colors.blue,
                      ),
                      _buildStatCard(
                        title: 'Coins Earned',
                        value: '${_stats?.coinsEarned ?? 0}',
                        icon: Icons.monetization_on,
                        color: Colors.amber,
                      ),
                      _buildStatCard(
                        title: 'Referrals',
                        value:
                            '${_stats?.referredCount ?? 0}/${_stats?.maxReferrals ?? 10}',
                        icon: Icons.people,
                        color: Colors.green,
                      ),
                      _buildStatCard(
                        title: 'Per Referral',
                        value: '+20',
                        icon: Icons.card_giftcard,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Referral Code Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Referral Code',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue[200]!,
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _stats?.code ?? 'N/A',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 32,
                                      ),
                                ),
                                IconButton(
                                  onPressed: _copyReferralCode,
                                  icon: const Icon(Icons.copy),
                                  tooltip: 'Copy code',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _shareReferralCode,
                              icon: const Icon(Icons.share),
                              label: const Text('Share Code'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Referral History
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'People You Referred',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),

                if (_history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No referrals yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Share your code to start earning!',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final referral = _history[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(referral.userName),
                            subtitle: Text('@${referral.userUsername}'),
                            trailing: Chip(
                              label: Text(
                                referral.rewardGiven ? 'Completed' : 'Pending',
                              ),
                              backgroundColor: referral.rewardGiven
                                  ? Colors.green[100]
                                  : Colors.orange[100],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),

                // Info Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                'How it works',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(color: Colors.blue[700]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '• Share your referral code with friends\n'
                            '• They enter the code during signup\n'
                            '• Both of you earn 20 coins\n'
                            '• No limit to your earnings!',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
