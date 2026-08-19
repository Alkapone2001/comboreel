import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/monetization_repository.dart';
import '../data/store_purchase_service.dart';
import '../domain/store_purchase.dart';
import '../domain/wallet_snapshot.dart';

class CoinsScreen extends StatefulWidget {
  const CoinsScreen({
    super.key,
    required this.repository,
    required this.store,
    required this.viewerId,
  });
  final MonetizationRepository repository;
  final StorePurchaseService store;
  final String? viewerId;

  @override
  State<CoinsScreen> createState() => _CoinsScreenState();
}

class _CoinsScreenState extends State<CoinsScreen> {
  late Future<WalletSnapshot> _wallet;
  late Future<List<StoreProduct>> _products;
  StreamSubscription<StorePurchaseUpdate>? _purchaseSubscription;
  String? _processingProductId;

  @override
  void initState() {
    super.initState();
    _reload();
    _products = widget.store.loadProducts();
    _purchaseSubscription = widget.store.updates.listen(_handlePurchase);
  }

  @override
  void dispose() {
    unawaited(_purchaseSubscription?.cancel());
    super.dispose();
  }

  void _reload() {
    final id = widget.viewerId;
    _wallet = id == null
        ? Future.value(const WalletSnapshot(balance: 0, transactions: []))
        : widget.repository.wallet(id);
  }

  Future<void> _handlePurchase(StorePurchaseUpdate purchase) async {
    if (!mounted) return;
    if (purchase.status == StorePurchaseStatus.pending) {
      setState(() => _processingProductId = purchase.productId);
      return;
    }
    if (purchase.status == StorePurchaseStatus.cancelled) {
      setState(() => _processingProductId = null);
      return;
    }
    if (purchase.status == StorePurchaseStatus.failed) {
      setState(() => _processingProductId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(purchase.error ?? 'The purchase failed.')),
      );
      return;
    }
    try {
      final result = await widget.repository.verifyMobilePurchase(purchase);
      if (!result.accepted) throw StateError('Purchase was not accepted');
      await widget.store.complete(purchase);
      if (!mounted) return;
      setState(() {
        _processingProductId = null;
        _reload();
      });
      final message = result.premiumUntil == null
          ? 'Coins added to your wallet.'
          : 'Premium is active.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _processingProductId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Purchase verification is pending. Use Restore Purchases to retry.',
          ),
        ),
      );
    }
  }

  Future<void> _buy(StoreProduct product) async {
    final userId = widget.viewerId;
    if (userId == null || _processingProductId != null) return;
    setState(() => _processingProductId = product.id);
    try {
      await widget.store.purchase(product, userId: userId);
    } catch (error) {
      if (!mounted) return;
      setState(() => _processingProductId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _restore() async {
    final userId = widget.viewerId;
    if (userId == null) return;
    try {
      await widget.store.restore(userId: userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checking your store purchases…')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases could not be restored.')),
        );
      }
    }
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
              FutureBuilder<List<StoreProduct>>(
                future: _products,
                builder: (context, productSnapshot) {
                  if (productSnapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final products =
                      productSnapshot.data ?? const <StoreProduct>[];
                  if (products.isEmpty) {
                    return const Text(
                      'Purchases are available in the iOS and Android apps.',
                      style: TextStyle(color: AppColors.muted),
                    );
                  }
                  final coinPacks = products
                      .where((item) => item.kind == StoreProductKind.coinPack)
                      .toList();
                  final premium = products
                      .where(
                        (item) =>
                            item.kind == StoreProductKind.premiumSubscription,
                      )
                      .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...coinPacks.map(
                        (product) => _PurchaseOption(
                          product: product,
                          loading: _processingProductId == product.id,
                          highlighted: product.coinAmount == 120,
                          onTap: () => _buy(product),
                        ),
                      ),
                      if (premium.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Text(
                          'Go Premium',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Unlimited episodes and no rewarded ads.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 12),
                        ...premium.map(
                          (product) => _PurchaseOption(
                            product: product,
                            loading: _processingProductId == product.id,
                            onTap: () => _buy(product),
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed: _restore,
                            child: const Text('Restore Purchases'),
                          ),
                        ),
                      ],
                    ],
                  );
                },
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
    required this.product,
    required this.loading,
    required this.onTap,
    this.highlighted = false,
  });
  final StoreProduct product;
  final bool loading;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Card(
    color: highlighted ? const Color(0xFF28200F) : AppColors.surface,
    child: ListTile(
      onTap: loading ? null : onTap,
      leading: const Icon(Icons.monetization_on_rounded, color: AppColors.gold),
      title: Text(
        product.title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(product.description),
      trailing: loading
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              product.price,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
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
