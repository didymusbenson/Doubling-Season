import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/iap_service.dart';
import '../models/heart_style.dart';
import 'heart_icon.dart';

/// Bottom-sheet tier selector for the tip-jar IAP.
///
/// Shows three non-consumable tiers (Thank You, Play, Collector) with live
/// store pricing, an "owned" indicator for previously-purchased tiers, and a
/// restore button. Returns `true` to the caller if a purchase completed.
class PurchaseMenu extends StatefulWidget {
  final String? scrollToTier;

  const PurchaseMenu({
    super.key,
    this.scrollToTier,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? scrollToTier,
  }) async {
    return showModalBottomSheet<bool>(
      context: context,
      builder: (context) => PurchaseMenu(scrollToTier: scrollToTier),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }

  @override
  State<PurchaseMenu> createState() => _PurchaseMenuState();
}

class _PurchaseMenuState extends State<PurchaseMenu> {
  final IAPService _iapService = IAPService();
  List<ProductDetails> _products = [];
  bool _isLoading = true;
  bool _isPurchasing = false;
  String? _error;
  String? _purchasingProductId;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final available = await _iapService.isAvailable();
      if (!available) {
        setState(() {
          _error = 'In-app purchases are not available on this device.';
          _isLoading = false;
        });
        return;
      }

      final products = await _iapService.getProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });

      if (products.isEmpty) {
        setState(() {
          _error = 'Unable to load products. Please try again later.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load products: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePurchase(String productId) async {
    bool isOwned = false;
    switch (productId) {
      case IAPService.thankYouId:
        isOwned = _iapService.hasThankYouTier();
        break;
      case IAPService.playId:
        isOwned = _iapService.hasPlayTier();
        break;
      case IAPService.collectorId:
        isOwned = _iapService.hasCollectorTier();
        break;
    }

    if (isOwned) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already own this tier!')),
        );
      }
      return;
    }

    setState(() {
      _isPurchasing = true;
      _purchasingProductId = productId;
    });

    try {
      await _iapService.buyProduct(productId);
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        _showSuccessDialog(productId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _purchasingProductId = null;
        });
      }
    }
  }

  void _showSuccessDialog(String productId) {
    String tierName = 'supporter';
    switch (productId) {
      case IAPService.thankYouId:
        tierName = 'Thank You';
        break;
      case IAPService.playId:
        tierName = 'Play';
        break;
      case IAPService.collectorId:
        tierName = 'Collector';
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thank You!'),
        content: Text(
          'Thank you for your support! You\'re now a $tierName supporter.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRestorePurchases() async {
    setState(() => _isPurchasing = true);

    try {
      await _iapService.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchases restored successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore purchases: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support Tripling Season',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Help keep Tripling Season ad-free and buy a pack for the dev.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildContent(scrollController),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: TextButton(
                onPressed: _isPurchasing ? null : _handleRestorePurchases,
                child: _isPurchasing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Restore Purchases'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (kIsWeb) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'In-app purchases are not available on the web.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.help_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Nothing to see here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please try again.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loadProducts,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildTierCard(
          productId: IAPService.thankYouId,
          tierName: 'Say Thanks',
          heartStyle: HeartStyle.red(),
          description:
              'Support the developer and unlock the exclusive red heart badge. Show your appreciation for Tripling Season!',
          isHighlighted: widget.scrollToTier == 'thank_you',
        ),
        _buildTierCard(
          productId: IAPService.playId,
          tierName: 'Say Thanks with a Play Booster',
          heartStyle: HeartStyle.blue(),
          description:
              'Buy the developer a pack of cards and unlock the exclusive blue heart badge. Show your appreciation for Tripling Season!',
          isHighlighted: widget.scrollToTier == 'play',
        ),
        _buildTierCard(
          productId: IAPService.collectorId,
          tierName: 'Say Thanks with a Collector Booster',
          heartStyle: HeartStyle.rainbow(),
          description:
              'Buy the developer a collector pack and unlock the exclusive customizable WUBRG heart badge. Get full Tripling Season supporter bragging rights!',
          isHighlighted: widget.scrollToTier == 'collector',
        ),
      ],
    );
  }

  Widget _buildTierCard({
    required String productId,
    required String tierName,
    required HeartStyle heartStyle,
    String? description,
    bool isHighlighted = false,
  }) {
    ProductDetails? product;
    try {
      product = _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      // Product not found — leave price blank.
    }

    bool isOwned = false;
    switch (productId) {
      case IAPService.thankYouId:
        isOwned = _iapService.hasThankYouTier();
        break;
      case IAPService.playId:
        isOwned = _iapService.hasPlayTier();
        break;
      case IAPService.collectorId:
        isOwned = _iapService.hasCollectorTier();
        break;
    }

    final isPurchasingThis =
        _isPurchasing && _purchasingProductId == productId;

    return Card(
      elevation: isHighlighted ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isHighlighted
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isPurchasingThis ? null : () => _handlePurchase(productId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      tierName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      softWrap: true,
                    ),
                  ),
                  if (product != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      product.price,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  HeartIcon(style: heartStyle, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '${heartStyle.name} Heart',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.7),
                      ),
                ),
              ],
              if (isOwned || isPurchasingThis) ...[
                const SizedBox(height: 12),
                if (isPurchasingThis)
                  const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Processing...'),
                    ],
                  )
                else
                  Opacity(
                    opacity: 0.6,
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PURCHASED',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
