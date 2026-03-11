import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../../core/services/revenuecat_service.dart';

/// Bottom sheet presented when a user attempts to access a Pro feature.
class PaywallSheet extends StatefulWidget {
  const PaywallSheet({super.key});

  /// Displays the paywall sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PaywallSheet(),
    );
  }

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  Offerings? _offerings;
  bool _isLoading = true;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _fetchOfferings();
  }

  Future<void> _fetchOfferings() async {
    final offerings = await RevenueCatService.getOfferings();
    if (mounted) {
      setState(() {
        _offerings = offerings;
        _isLoading = false;
      });
    }
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() => _isPurchasing = true);
    final success = await RevenueCatService.purchasePackage(package);
    if (!mounted) return;
    setState(() => _isPurchasing = false);
    
    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase unsuccessful or cancelled.')),
      );
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isPurchasing = true);
    final success = await RevenueCatService.restorePurchases();
    if (!mounted) return;
    setState(() => _isPurchasing = false);
    
    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchases restored successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active purchases found to restore.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24).copyWith(bottom: MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Unlock LumaCraft Pro',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Value Propositions
          _buildValueProp(Icons.hd_outlined, 'Export in 1080p and 4K'),
          _buildValueProp(Icons.speed_outlined, 'Unlock smooth 60 FPS'),
          _buildValueProp(Icons.water_drop_outlined, 'Remove LumaCraft watermark'),
          
          const SizedBox(height: 32),
          
          // Primary Action
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_offerings?.current?.availablePackages.isNotEmpty == true)
            _buildPurchaseButton(_offerings!.current!.availablePackages.first)
          else
            _buildUnavailableState(),
            
          const SizedBox(height: 16),
          
          // Restore Action
          TextButton(
            onPressed: _isPurchasing ? null : _restorePurchases,
            child: const Text('Restore Purchases', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _buildValueProp(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton(Package package) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _isPurchasing ? null : () => _purchasePackage(package),
      child: _isPurchasing
          ? const SizedBox(
              height: 24, 
              width: 24, 
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
            )
          : Text(
              'Upgrade for ${package.storeProduct.priceString}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
    );
  }

  Widget _buildUnavailableState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'Store offerings are currently unavailable.',
          style: TextStyle(color: Colors.white54, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
