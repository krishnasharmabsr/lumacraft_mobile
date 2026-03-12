import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft_mobile/core/services/revenuecat_service.dart';
import 'package:lumacraft_mobile/features/monetization/presentation/screens/paywall_sheet.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  group('PaywallSheet', () {
    testWidgets('shows cleaned pricing copy for available plans', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(
          PaywallSheet(
            initialPackages: [_buildPackage(type: PackageType.monthly)],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Plans and pricing update automatically for your region.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Store pricing is shown live from RevenueCat and your app store.',
        ),
        findsNothing,
      );
    });

    testWidgets('shows restore loading state and no-purchases feedback', (
      tester,
    ) async {
      final completer = Completer<RestorePurchasesResult>();

      await tester.pumpWidget(
        _buildHarness(
          PaywallSheet(
            initialPackages: [_buildPackage(type: PackageType.monthly)],
            restorePurchases: () => completer.future,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore Purchases'));
      await tester.pump();

      expect(find.text('Restoring...'), findsOneWidget);

      completer.complete(const RestorePurchasesResult.noPurchasesFound());
      await tester.pumpAndSettle();

      expect(
        find.text('No previous purchases were found for this account.'),
        findsOneWidget,
      );
    });

    testWidgets('shows restore failure feedback', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          PaywallSheet(
            initialPackages: [_buildPackage(type: PackageType.monthly)],
            restorePurchases: () async => const RestorePurchasesResult.failed(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore Purchases'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not restore purchases right now. Please try again.'),
        findsOneWidget,
      );
    });
  });
}

Widget _buildHarness(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Package _buildPackage({required PackageType type}) {
  return Package(
    'pro_${type.name}',
    type,
    StoreProduct(
      'pro_${type.name}',
      'Test description',
      'LumaCraft Pro ${type.name}',
      9.99,
      '\$9.99',
      'USD',
      subscriptionPeriod: 'P1M',
      pricePerMonthString: '\$9.99',
    ),
    const PresentedOfferingContext('default', null, null),
  );
}
