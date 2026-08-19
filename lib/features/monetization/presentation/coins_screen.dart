import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/monetization_repository.dart';
import '../domain/wallet_snapshot.dart';

class CoinsScreen extends StatefulWidget {
  const CoinsScreen({
    super.key,
    required this.repository,
    required this.viewerId,
  });
  final MonetizationRepository repository;
  final String? viewerId;

  @override
  State<CoinsScreen> createState() => _CoinsScreenState();
}

class _CoinsScreenState extends State<CoinsScreen> {
  late Future<WalletSnapshot> _wallet;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final id = widget.viewerId;
    _wallet = id == null
        ? Future.value(const WalletSnapshot(balance: 0, transactions: []))
        : widget.repository.wallet(id);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: FutureBuilder<WalletSnapshot>(
      future: _wallet,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _CoinsMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Wallet unavailable',
            message: 'We could not load your balance.',
            action: TextButton(
              onPressed: () => setState(_reload),
              child: const Text('Try again'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (widget.viewerId == null) {
          return const _CoinsMessage(
            icon: Icons.lock_outline_rounded,
            title: 'Sign in to use coins',
            message:
                'Your wallet and unlocks are securely tied to your account.',
          );
        }
        final wallet = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async {
            setState(_reload);
            await _wallet;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
            children: [
              Text(
                'Coins & rewards',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6F4A13), Color(0xFF2A1B08)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: .35),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: AppColors.gold,
                      size: 42,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${wallet.balance}',
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'available coins',
                      style: TextStyle(color: Color(0xFFE7C989)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Get more coins',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const _PurchaseOption(
                coins: 50,
                label: 'Starter pack',
                price: 'Store setup pending',
              ),
              const _PurchaseOption(
                coins: 120,
                label: 'Most popular',
                price: 'Store setup pending',
                highlighted: true,
              ),
              const _PurchaseOption(
                coins: 300,
                label: 'Best value',
                price: 'Store setup pending',
              ),
              const SizedBox(height: 28),
              Text(
                'Recent activity',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              if (wallet.transactions.isEmpty)
                const Text(
                  'No coin activity yet.',
                  style: TextStyle(color: AppColors.muted),
                )
              else
                ...wallet.transactions.map(_ActivityTile.new),
            ],
          ),
        );
      },
    ),
  );
}

class _PurchaseOption extends StatelessWidget {
  const _PurchaseOption({
    required this.coins,
    required this.label,
    required this.price,
    this.highlighted = false,
  });
  final int coins;
  final String label;
  final String price;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Card(
    color: highlighted ? const Color(0xFF28200F) : AppColors.surface,
    child: ListTile(
      leading: const Icon(Icons.monetization_on_rounded, color: AppColors.gold),
      title: Text(
        '$coins coins',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(label),
      trailing: Text(
        price,
        style: const TextStyle(color: AppColors.muted, fontSize: 11),
      ),
    ),
  );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile(this.activity);
  final CoinActivity activity;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: (activity.amount > 0 ? AppColors.gold : AppColors.coral)
          .withValues(alpha: .14),
      child: Icon(
        activity.amount > 0 ? Icons.add_rounded : Icons.play_arrow_rounded,
        color: activity.amount > 0 ? AppColors.gold : AppColors.coral,
      ),
    ),
    title: Text(
      activity.reason,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: Text(
      'Balance: ${activity.balanceAfter}',
      style: const TextStyle(color: AppColors.muted),
    ),
    trailing: Text(
      '${activity.amount > 0 ? '+' : ''}${activity.amount}',
      style: TextStyle(
        fontWeight: FontWeight.w900,
        color: activity.amount > 0 ? AppColors.gold : Colors.white,
      ),
    ),
  );
}

class _CoinsMessage extends StatelessWidget {
  const _CoinsMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.gold),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          action ?? const SizedBox.shrink(),
        ],
      ),
    ),
  );
}
