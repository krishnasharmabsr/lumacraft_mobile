import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/app_config.dart';
import 'pro_gate.dart';

enum RestorePurchasesStatus { restored, noPurchasesFound, failed }

class RestorePurchasesResult {
  final RestorePurchasesStatus status;

  const RestorePurchasesResult._(this.status);

  const RestorePurchasesResult.restored()
    : this._(RestorePurchasesStatus.restored);

  const RestorePurchasesResult.noPurchasesFound()
    : this._(RestorePurchasesStatus.noPurchasesFound);

  const RestorePurchasesResult.failed() : this._(RestorePurchasesStatus.failed);
}

class RevenueCatService {
  static const String _entitlementId = 'pro';
  static bool _isConfigured = false;

  /// Initializes the Purchases SDK.
  /// Should be called early in the app lifecycle.
  static Future<void> init() async {
    if (AppConfig.revenueCatAndroidKey.isEmpty) {
      developer.log(
        '[RevenueCat] No API key present. Fallback to free tier.',
        name: 'Monetization',
      );
      return;
    }

    try {
      await Purchases.setLogLevel(LogLevel.info);

      PurchasesConfiguration configuration = PurchasesConfiguration(
        AppConfig.revenueCatAndroidKey,
      );
      await Purchases.configure(configuration);
      _isConfigured = true;

      developer.log(
        '[RevenueCat] Initialized successfully.',
        name: 'Monetization',
      );
      await refreshEntitlement();

      // Listen to customer info changes (e.g., from an out-of-app purchase)
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updateProStatus(customerInfo);
      });
    } catch (e) {
      developer.log(
        '[RevenueCat] Init error: $e',
        name: 'Monetization',
        error: e,
      );
    }
  }

  /// Refreshes the local entitlement status.
  static Future<void> refreshEntitlement() async {
    if (!_isConfigured) return;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _updateProStatus(customerInfo);
    } catch (e) {
      developer.log(
        '[RevenueCat] Fetch customer info error: $e',
        name: 'Monetization',
        error: e,
      );
    }
  }

  /// Updates the global ProGate access state based on CustomerInfo.
  static void _updateProStatus(CustomerInfo customerInfo) {
    if (AppConfig.isDevProOverrideEnabled) {
      developer.log(
        '[RevenueCat] Skipping native entitlement update because DEV_FORCE_PRO is active.',
        name: 'Monetization',
      );
      return;
    }

    final entitlement = customerInfo.entitlements.all[_entitlementId];
    final bool isPro = entitlement != null && entitlement.isActive;
    developer.log(
      '[RevenueCat] Entitlement $_entitlementId active: $isPro',
      name: 'Monetization',
    );

    ProGate.isPro = isPro;
  }

  /// Fetches the current offerings configured in RevenueCat.
  static Future<Offerings?> getOfferings() async {
    if (!_isConfigured) return null;
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      developer.log(
        '[RevenueCat] getOfferings error: $e',
        name: 'Monetization',
        error: e,
      );
      return null;
    }
  }

  /// Attempts to purchase the given package.
  /// Returns [true] if the purchase succeeded and the 'pro' entitlement is active.
  static Future<bool> purchasePackage(Package package) async {
    if (!_isConfigured) return false;
    try {
      developer.log(
        '[RevenueCat] Attempting to purchase package: ${package.identifier}',
        name: 'Monetization',
      );
      // ignore: deprecated_member_use
      final result = await Purchases.purchasePackage(package);
      _updateProStatus(result.customerInfo);
      return ProGate.isPro;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        developer.log(
          '[RevenueCat] Purchase failed: $e',
          name: 'Monetization',
          error: e,
        );
      }
      return false;
    } catch (e) {
      developer.log(
        '[RevenueCat] Unknown purchase error: $e',
        name: 'Monetization',
        error: e,
      );
      return false;
    }
  }

  /// Attempts to restore prior purchases.
  /// Returns a typed result so the UI can distinguish "nothing restored"
  /// from a real failure.
  static Future<RestorePurchasesResult> restorePurchases() async {
    if (!_isConfigured) return const RestorePurchasesResult.failed();
    try {
      developer.log(
        '[RevenueCat] Attempting to restore purchases...',
        name: 'Monetization',
      );
      final customerInfo = await Purchases.restorePurchases();
      _updateProStatus(customerInfo);
      return ProGate.isPro
          ? const RestorePurchasesResult.restored()
          : const RestorePurchasesResult.noPurchasesFound();
    } catch (e) {
      developer.log(
        '[RevenueCat] Restore failed: $e',
        name: 'Monetization',
        error: e,
      );
      return const RestorePurchasesResult.failed();
    }
  }
}
