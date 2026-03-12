import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/revenuecat_service.dart';
import '../models/paywall_package_option.dart';

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
  List<PaywallPackageOption> _packageOptions = const [];
  Package? _selectedPackage;
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
      final availablePackages =
          offerings?.current?.availablePackages ?? const <Package>[];
      final options = PaywallPackageCatalog.build(availablePackages);
      setState(() {
        _packageOptions = options;
        _selectedPackage = PaywallPackageCatalog.preferredSelection(options);
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
    final mediaQuery = MediaQuery.of(context);
    final ctaPackage = _selectedPackage;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.88),
        decoration: const BoxDecoration(
          color: AppColors.scaffoldDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(
                  AppTheme.spacingXl,
                ).copyWith(bottom: AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: AppTheme.spacingLg),
                    _buildHeroCard(),
                    const SizedBox(height: AppTheme.spacingLg),
                    _buildBenefitList(),
                    const SizedBox(height: AppTheme.spacingLg),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spacingXxl,
                        ),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_packageOptions.isNotEmpty)
                      _buildPackageSelector()
                    else
                      _buildUnavailableState(),
                  ],
                ),
              ),
            ),
            _buildFooter(ctaPackage),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: AppColors.scaffoldDark,
            size: 26,
          ),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LumaCraft Pro',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Export sharper, smoother, and cleaner with premium unlocks built for serious editing.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardDark,
            AppColors.cardDarkAlt.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unlock the full export toolkit',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppTheme.spacingSm),
          Text(
            'Choose a plan to remove restrictions, keep your exports clean, and stay uninterrupted.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitList() {
    return Column(
      children: const [
        _BenefitRow(
          icon: Icons.high_quality_rounded,
          title: 'Export in 1080p and 4K',
          subtitle: 'Unlock premium resolution options for final output.',
        ),
        SizedBox(height: AppTheme.spacingMd),
        _BenefitRow(
          icon: Icons.speed_rounded,
          title: 'Unlock 60 FPS',
          subtitle: 'Enable smoother motion for action shots and fast edits.',
        ),
        SizedBox(height: AppTheme.spacingMd),
        _BenefitRow(
          icon: Icons.layers_clear_rounded,
          title: 'Remove watermark',
          subtitle: 'Export clean branded-free renders on supported devices.',
        ),
        SizedBox(height: AppTheme.spacingMd),
        _BenefitRow(
          icon: Icons.hide_source_rounded,
          title: 'Remove ads',
          subtitle: 'Pro users never see interstitials in the export flow.',
        ),
      ],
    );
  }

  Widget _buildPackageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose your plan',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        const Text(
          'Store pricing is shown live from RevenueCat and your app store.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        ..._packageOptions.map(_buildPackageCard),
      ],
    );
  }

  Widget _buildPackageCard(PaywallPackageOption option) {
    final isSelected =
        _selectedPackage?.identifier == option.package.identifier;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: _isPurchasing
              ? null
              : () => setState(() => _selectedPackage = option.package),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.cardDark
                  : AppColors.cardDarkAlt.withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: isSelected
                    ? AppColors.accent
                    : option.isPrimary
                    ? AppColors.accent.withValues(alpha: 0.35)
                    : AppColors.divider,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            option.subtitle,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (option.badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.accentGradient,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          option.badgeText!,
                          style: const TextStyle(
                            color: AppColors.scaffoldDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Row(
                  children: [
                    Text(
                      option.priceText,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      child: Text(
                        option.detailText,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnavailableState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.cardDarkAlt.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 20),
              SizedBox(width: AppTheme.spacingSm),
              Text(
                'Plans unavailable right now',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          const Text(
            'We could not load live subscription packages from the store. Pricing is hidden until packages are available again.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          OutlinedButton.icon(
            onPressed: _isLoading || _isPurchasing
                ? null
                : () {
                    setState(() => _isLoading = true);
                    _fetchOfferings();
                  },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry loading plans'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Package? ctaPackage) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingXl,
        AppTheme.spacingLg,
        AppTheme.spacingXl,
        AppTheme.spacingXl,
      ),
      decoration: BoxDecoration(
        color: AppColors.scaffoldDark,
        border: Border(
          top: BorderSide(color: AppColors.divider.withValues(alpha: 0.7)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: (_isPurchasing || ctaPackage == null)
                ? null
                : () => _purchasePackage(ctaPackage),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.scaffoldDark,
            ),
            child: _isPurchasing
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.scaffoldDark,
                    ),
                  )
                : Text(
                    PaywallPackageCatalog.ctaLabelFor(ctaPackage),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isPurchasing ? null : _restorePurchases,
                  child: const Text(
                    'Restore Purchases',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _isPurchasing
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Not now',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Subscriptions renew automatically unless cancelled through your store account settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.cardDarkAlt.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
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
