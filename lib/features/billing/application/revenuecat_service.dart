import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:physi_log/features/billing/domain/revenuecat_catalog.dart';
import 'package:physi_log/features/billing/domain/revenuecat_environment.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as purchases;

abstract interface class RevenueCatClient {
  Future<void> configure({required String apiKey, required String? appUserId});

  Future<bool> hasActiveEntitlement(String entitlementId);
}

class PurchasesRevenueCatClient implements RevenueCatClient {
  const PurchasesRevenueCatClient();

  @override
  Future<void> configure({
    required String apiKey,
    required String? appUserId,
  }) async {
    final configuration = purchases.PurchasesConfiguration(apiKey)
      ..appUserID = appUserId;
    await purchases.Purchases.configure(configuration);
  }

  @override
  Future<bool> hasActiveEntitlement(String entitlementId) async {
    final customerInfo = await purchases.Purchases.getCustomerInfo();
    return customerInfo.entitlements.active.containsKey(entitlementId);
  }
}

class RevenueCatService {
  const RevenueCatService({
    RevenueCatClient client = const PurchasesRevenueCatClient(),
    RevenueCatEnvironment environment = RevenueCatEnvironment.fromEnvironment,
    RevenueCatPlatform? platform,
  }) : _client = client,
       _environment = environment,
       _platform = platform;

  final RevenueCatClient _client;
  final RevenueCatEnvironment _environment;
  final RevenueCatPlatform? _platform;

  Future<bool> configure({String? appUserId}) async {
    final platform = _platform ?? _currentPlatform();
    if (platform == null) {
      return false;
    }

    final apiKey = _environment.apiKeyFor(platform);
    if (apiKey == null) {
      return false;
    }

    final normalizedAppUserId = appUserId?.trim();
    await _client.configure(
      apiKey: apiKey,
      appUserId: normalizedAppUserId?.isEmpty ?? true
          ? null
          : normalizedAppUserId,
    );
    return true;
  }

  Future<bool> hasPersonalFamilyEntitlement() {
    return _client.hasActiveEntitlement(
      RevenueCatCatalog.personalFamilyEntitlementId,
    );
  }

  Future<bool> hasTeamEntitlement() {
    return _client.hasActiveEntitlement(RevenueCatCatalog.teamEntitlementId);
  }

  RevenueCatPlatform? _currentPlatform() {
    if (kIsWeb) {
      return null;
    }
    if (Platform.isIOS) {
      return RevenueCatPlatform.ios;
    }
    if (Platform.isAndroid) {
      return RevenueCatPlatform.android;
    }
    return null;
  }
}
