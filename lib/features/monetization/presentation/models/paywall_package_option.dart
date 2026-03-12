import 'package:purchases_flutter/purchases_flutter.dart';

enum PaywallPlanKind { yearly, monthly, other }

class PaywallPackageOption {
  final Package package;
  final PaywallPlanKind kind;
  final String title;
  final String subtitle;
  final String priceText;
  final String detailText;
  final String? badgeText;
  final bool isPrimary;

  const PaywallPackageOption({
    required this.package,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.priceText,
    required this.detailText,
    this.badgeText,
    required this.isPrimary,
  });
}

class PaywallPackageCatalog {
  const PaywallPackageCatalog._();

  static List<PaywallPackageOption> build(List<Package> packages) {
    if (packages.isEmpty) return const [];

    final yearly = _firstByKind(packages, PaywallPlanKind.yearly);
    final monthly = _firstByKind(packages, PaywallPlanKind.monthly);

    final ordered = <Package>[];
    final seen = <String>{};

    void addPackage(Package? package) {
      if (package == null) return;
      if (seen.add(package.identifier)) {
        ordered.add(package);
      }
    }

    addPackage(yearly);
    addPackage(monthly);

    for (final package in packages) {
      addPackage(package);
    }

    return ordered.map((package) {
      final kind = classify(package);
      final isYearlyPrimary = yearly != null && monthly != null;
      final badgeText =
          kind == PaywallPlanKind.yearly && yearly != null && monthly != null
          ? _yearlyBadge(yearly, monthly)
          : null;
      return PaywallPackageOption(
        package: package,
        kind: kind,
        title: _titleFor(package, kind),
        subtitle: _subtitleFor(kind),
        priceText: package.storeProduct.priceString,
        detailText: _detailFor(package, kind),
        badgeText: badgeText,
        isPrimary: kind == PaywallPlanKind.yearly && isYearlyPrimary,
      );
    }).toList();
  }

  static Package? preferredSelection(List<PaywallPackageOption> options) {
    if (options.isEmpty) return null;
    final yearly = options.where(
      (option) => option.kind == PaywallPlanKind.yearly,
    );
    if (yearly.isNotEmpty) return yearly.first.package;
    return options.first.package;
  }

  static String ctaLabelFor(Package? package) {
    if (package == null) return 'Plans unavailable';
    final kind = classify(package);
    final title = _titleFor(package, kind);
    return 'Continue with $title • ${package.storeProduct.priceString}';
  }

  static PaywallPlanKind classify(Package package) {
    switch (package.packageType) {
      case PackageType.annual:
        return PaywallPlanKind.yearly;
      case PackageType.monthly:
        return PaywallPlanKind.monthly;
      default:
        final identifier = package.identifier.toLowerCase();
        if (identifier.contains('annual') || identifier.contains('year')) {
          return PaywallPlanKind.yearly;
        }
        if (identifier.contains('month')) {
          return PaywallPlanKind.monthly;
        }
        return PaywallPlanKind.other;
    }
  }

  static Package? _firstByKind(List<Package> packages, PaywallPlanKind kind) {
    for (final package in packages) {
      if (classify(package) == kind) return package;
    }
    return null;
  }

  static String _titleFor(Package package, PaywallPlanKind kind) {
    switch (kind) {
      case PaywallPlanKind.yearly:
        return 'Yearly';
      case PaywallPlanKind.monthly:
        return 'Monthly';
      case PaywallPlanKind.other:
        final title = package.storeProduct.title.trim();
        if (title.isEmpty) return 'Pro Plan';
        final cleanTitle = title.split('(').first.trim();
        return cleanTitle.isEmpty ? 'Pro Plan' : cleanTitle;
    }
  }

  static String _subtitleFor(PaywallPlanKind kind) {
    switch (kind) {
      case PaywallPlanKind.yearly:
        return 'Best for long-term creators';
      case PaywallPlanKind.monthly:
        return 'Flexible monthly billing';
      case PaywallPlanKind.other:
        return 'Available plan';
    }
  }

  static String _detailFor(Package package, PaywallPlanKind kind) {
    final product = package.storeProduct;
    switch (kind) {
      case PaywallPlanKind.yearly:
        if (product.pricePerMonthString != null &&
            product.pricePerMonthString!.isNotEmpty) {
          return '${product.pricePerMonthString} / month billed yearly';
        }
        return 'Billed once per year';
      case PaywallPlanKind.monthly:
        return 'Billed monthly';
      case PaywallPlanKind.other:
        final period = product.subscriptionPeriod;
        if (period == 'P1Y') return 'Billed yearly';
        if (period == 'P1M') return 'Billed monthly';
        if (period == 'P6M') return 'Billed every 6 months';
        if (period == 'P3M') return 'Billed every 3 months';
        return 'Store pricing from ${product.currencyCode}';
    }
  }

  static String _yearlyBadge(Package yearly, Package monthly) {
    final yearlyPrice = yearly.storeProduct.price;
    final monthlyPrice = monthly.storeProduct.price;
    if (yearlyPrice <= 0 || monthlyPrice <= 0) return 'Best Value';
    if (yearly.storeProduct.currencyCode != monthly.storeProduct.currencyCode) {
      return 'Best Value';
    }

    final annualMonthlyEquivalent = monthlyPrice * 12;
    if (annualMonthlyEquivalent <= yearlyPrice) return 'Best Value';

    final savings =
        (((annualMonthlyEquivalent - yearlyPrice) / annualMonthlyEquivalent) *
                100)
            .round();
    if (savings <= 0) return 'Best Value';
    return 'Best Value • Save $savings%';
  }
}
