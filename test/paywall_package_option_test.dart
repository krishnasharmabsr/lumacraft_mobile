import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft_mobile/features/monetization/presentation/models/paywall_package_option.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  group('PaywallPackageCatalog', () {
    test('prefers yearly first and highlights it when monthly exists', () {
      final monthly = _buildPackage(
        identifier: 'pro_monthly',
        type: PackageType.monthly,
        title: 'LumaCraft Pro Monthly',
        price: 9.99,
        priceString: '\$9.99',
        subscriptionPeriod: 'P1M',
      );
      final yearly = _buildPackage(
        identifier: 'pro_annual',
        type: PackageType.annual,
        title: 'LumaCraft Pro Annual',
        price: 59.99,
        priceString: '\$59.99',
        subscriptionPeriod: 'P1Y',
        pricePerMonthString: '\$5.00',
      );

      final options = PaywallPackageCatalog.build([monthly, yearly]);

      expect(options.map((option) => option.title).toList(), [
        'Yearly',
        'Monthly',
      ]);
      expect(options.first.isPrimary, true);
      expect(options.first.badgeText, contains('Best Value'));
      expect(
        PaywallPackageCatalog.preferredSelection(options)?.identifier,
        yearly.identifier,
      );
    });

    test('keeps real package fallback when monthly and yearly are absent', () {
      final weekly = _buildPackage(
        identifier: 'pro_weekly',
        type: PackageType.weekly,
        title: 'LumaCraft Pro Weekly',
        price: 4.99,
        priceString: '\$4.99',
        subscriptionPeriod: 'P1W',
      );

      final options = PaywallPackageCatalog.build([weekly]);

      expect(options, hasLength(1));
      expect(options.first.title, 'LumaCraft Pro Weekly');
      expect(options.first.badgeText, isNull);
      expect(
        PaywallPackageCatalog.ctaLabelFor(weekly),
        'Continue with LumaCraft Pro Weekly • \$4.99',
      );
    });

    test('falls back to unavailable CTA when no package is selected', () {
      expect(PaywallPackageCatalog.ctaLabelFor(null), 'Plans unavailable');
    });
  });
}

Package _buildPackage({
  required String identifier,
  required PackageType type,
  required String title,
  required double price,
  required String priceString,
  required String subscriptionPeriod,
  String? pricePerMonthString,
}) {
  return Package(
    identifier,
    type,
    StoreProduct(
      identifier,
      '$title description',
      title,
      price,
      priceString,
      'USD',
      subscriptionPeriod: subscriptionPeriod,
      pricePerMonthString: pricePerMonthString,
    ),
    const PresentedOfferingContext('default', null, null),
  );
}
