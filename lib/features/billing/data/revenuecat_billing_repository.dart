import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as purchases;

import '../domain/billing_catalog_failure.dart';
import '../domain/billing_customer_access.dart';
import '../domain/billing_product.dart';
import '../domain/billing_purchase_request.dart';
import '../domain/billing_purchase_result.dart';
import '../domain/billing_repository.dart';
import '../domain/billing_subscription.dart';
import '../domain/revenuecat_catalog.dart';
import '../domain/revenuecat_environment.dart';

class RevenueCatPackageSnapshot {
  const RevenueCatPackageSnapshot({
    required this.packageId,
    required this.productId,
    required this.title,
    required this.priceText,
  });

  final String packageId;
  final String productId;
  final String title;
  final String priceText;
}

class RevenueCatCustomerSnapshot {
  const RevenueCatCustomerSnapshot({
    required this.activeEntitlementIds,
    this.activeSubscriptions = const [],
    this.managementUrl,
  });

  final Set<String> activeEntitlementIds;
  final List<RevenueCatEntitlementSnapshot> activeSubscriptions;
  final String? managementUrl;
}

class RevenueCatEntitlementSnapshot {
  const RevenueCatEntitlementSnapshot({
    required this.entitlementId,
    required this.productId,
    required this.store,
    required this.isActive,
    required this.willRenew,
    this.productPlanIdentifier,
    this.expiresAt,
    this.unsubscribeDetectedAt,
    this.billingIssueDetectedAt,
  });

  final String entitlementId;
  final String productId;
  final BillingStore store;
  final bool isActive;
  final bool willRenew;

  /// Google Playで契約を開始したBase Plan ID。他Storeではnull。
  final String? productPlanIdentifier;
  final DateTime? expiresAt;
  final DateTime? unsubscribeDetectedAt;
  final DateTime? billingIssueDetectedAt;
}

class RevenueCatPurchaseRequest {
  const RevenueCatPurchaseRequest({
    required this.packageId,
    this.previousProductId,
    this.replacementMode,
  });

  final String packageId;
  final String? previousProductId;
  final BillingReplacementMode? replacementMode;
}

enum RevenueCatGatewayFailure { cancelled, failed }

BillingCatalogFailure revenueCatCatalogFailureFor(PlatformException error) {
  purchases.PurchasesErrorCode errorCode;
  try {
    errorCode = purchases.PurchasesErrorHelper.getErrorCode(error);
  } on Object {
    return BillingCatalogFailure.unknown;
  }

  if (errorCode == purchases.PurchasesErrorCode.configurationError) {
    final message = error.message ?? '';
    if (message.contains('no Test Store products registered')) {
      return BillingCatalogFailure.noTestStoreProducts;
    }
    if (message.contains('No packages could be found for offering')) {
      return BillingCatalogFailure.offeringEmpty;
    }
    if (message.contains(
      'None of the products registered in the RevenueCat dashboard',
    )) {
      return BillingCatalogFailure.productsUnavailable;
    }
  }

  return switch (errorCode) {
    purchases.PurchasesErrorCode.invalidCredentialsError =>
      BillingCatalogFailure.invalidCredentials,
    purchases.PurchasesErrorCode.configurationError =>
      BillingCatalogFailure.configuration,
    purchases.PurchasesErrorCode.invalidAppUserIdError =>
      BillingCatalogFailure.invalidAppUserId,
    purchases.PurchasesErrorCode.networkError => BillingCatalogFailure.network,
    purchases.PurchasesErrorCode.offlineConnectionError =>
      BillingCatalogFailure.offline,
    purchases.PurchasesErrorCode.apiEndpointBlocked =>
      BillingCatalogFailure.endpointBlocked,
    _ => BillingCatalogFailure.unknown,
  };
}

class RevenueCatGatewayException implements Exception {
  const RevenueCatGatewayException.cancelled()
    : failure = RevenueCatGatewayFailure.cancelled;

  const RevenueCatGatewayException.failed()
    : failure = RevenueCatGatewayFailure.failed;

  final RevenueCatGatewayFailure failure;
}

abstract interface class RevenueCatGateway {
  Future<void> configure({required String apiKey, required String? appUserId});

  Future<void> logIn(String appUserId);

  Future<List<RevenueCatPackageSnapshot>> fetchPackages(String offeringId);

  Future<RevenueCatCustomerSnapshot> purchase(
    RevenueCatPurchaseRequest request,
  );

  Future<RevenueCatCustomerSnapshot> restorePurchases();

  Future<RevenueCatCustomerSnapshot> getCustomerInfo({
    bool forceRefresh = false,
  });

  Stream<RevenueCatCustomerSnapshot> watchCustomerInfo();
}

abstract interface class RevenueCatSetupClient {
  Future<bool> get isConfigured;

  Future<String> get appUserId;

  Future<void> configure({required String apiKey, required String? appUserId});

  Future<void> logIn(String appUserId);
}

class PurchasesRevenueCatSetupClient implements RevenueCatSetupClient {
  @override
  Future<String> get appUserId => purchases.Purchases.appUserID;

  @override
  Future<bool> get isConfigured => purchases.Purchases.isConfigured;

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
  Future<void> logIn(String appUserId) async {
    await purchases.Purchases.logIn(appUserId);
  }
}

class PurchasesRevenueCatGateway implements RevenueCatGateway {
  PurchasesRevenueCatGateway({RevenueCatSetupClient? setupClient})
    : _setupClient = setupClient ?? PurchasesRevenueCatSetupClient();

  final RevenueCatSetupClient _setupClient;
  final _packagesById = <String, purchases.Package>{};

  @override
  Future<void> configure({
    required String apiKey,
    required String? appUserId,
  }) async {
    try {
      final alreadyConfigured = await _setupClient.isConfigured;
      assert(() {
        debugPrint(
          'RevenueCat configure input: '
          'testStore=${apiKey.startsWith('test_')} '
          'alreadyConfigured=$alreadyConfigured',
        );
        return true;
      }());
      if (alreadyConfigured) {
        if (appUserId != null) {
          final currentAppUserId = await _setupClient.appUserId;
          if (currentAppUserId != appUserId) {
            await _setupClient.logIn(appUserId);
          }
        }
        return;
      }

      await _setupClient.configure(apiKey: apiKey, appUserId: appUserId);
    } on PlatformException catch (error) {
      throw BillingCatalogException(revenueCatCatalogFailureFor(error));
    }
  }

  @override
  Future<List<RevenueCatPackageSnapshot>> fetchPackages(
    String offeringId,
  ) async {
    final purchases.Offerings offerings;
    try {
      offerings = await purchases.Purchases.getOfferings();
    } on PlatformException catch (error) {
      throw BillingCatalogException(revenueCatCatalogFailureFor(error));
    }
    final offering = offerings.getOffering(offeringId);
    if (offering == null) {
      _packagesById.clear();
      return const [];
    }

    _packagesById
      ..clear()
      ..addEntries(
        offering.availablePackages.map(
          (package) => MapEntry(package.identifier, package),
        ),
      );

    return offering.availablePackages
        .map(
          (package) => RevenueCatPackageSnapshot(
            packageId: package.identifier,
            productId: package.storeProduct.identifier,
            title: package.storeProduct.title,
            priceText: package.storeProduct.priceString,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<RevenueCatCustomerSnapshot> getCustomerInfo({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await purchases.Purchases.invalidateCustomerInfoCache();
    }
    final customerInfo = await purchases.Purchases.getCustomerInfo();
    return _toCustomerSnapshot(customerInfo);
  }

  @override
  Future<void> logIn(String appUserId) async {
    await _setupClient.logIn(appUserId);
  }

  @override
  Future<RevenueCatCustomerSnapshot> purchase(
    RevenueCatPurchaseRequest request,
  ) async {
    final package = _packagesById[request.packageId];
    if (package == null) {
      throw const RevenueCatGatewayException.failed();
    }

    try {
      final previousProductId = request.previousProductId;
      final productChangeInfo = previousProductId == null
          ? null
          : purchases.StoreProductChangeInfo(
              previousProductId,
              replacementMode: revenueCatStoreReplacementModeFor(
                request.replacementMode,
              ),
            );
      final result = await purchases.Purchases.purchase(
        purchases.PurchaseParams.package(
          package,
          productChangeInfo: productChangeInfo,
        ),
      );
      return _toCustomerSnapshot(result.customerInfo);
    } on PlatformException catch (error) {
      final errorCode = purchases.PurchasesErrorHelper.getErrorCode(error);
      if (errorCode == purchases.PurchasesErrorCode.purchaseCancelledError) {
        throw const RevenueCatGatewayException.cancelled();
      }
      throw const RevenueCatGatewayException.failed();
    }
  }

  @override
  Future<RevenueCatCustomerSnapshot> restorePurchases() async {
    final customerInfo = await purchases.Purchases.restorePurchases();
    return _toCustomerSnapshot(customerInfo);
  }

  @override
  Stream<RevenueCatCustomerSnapshot> watchCustomerInfo() {
    return Stream.multi((controller) {
      void listener(purchases.CustomerInfo customerInfo) {
        controller.add(_toCustomerSnapshot(customerInfo));
      }

      purchases.Purchases.addCustomerInfoUpdateListener(listener);
      controller.onCancel = () {
        purchases.Purchases.removeCustomerInfoUpdateListener(listener);
      };
    }, isBroadcast: true);
  }

  RevenueCatCustomerSnapshot _toCustomerSnapshot(
    purchases.CustomerInfo customerInfo,
  ) {
    return RevenueCatCustomerSnapshot(
      activeEntitlementIds: customerInfo.entitlements.active.keys.toSet(),
      activeSubscriptions: customerInfo.entitlements.active.values
          .map(_toEntitlementSnapshot)
          .toList(growable: false),
      managementUrl: customerInfo.managementURL,
    );
  }

  RevenueCatEntitlementSnapshot _toEntitlementSnapshot(
    purchases.EntitlementInfo entitlement,
  ) {
    return RevenueCatEntitlementSnapshot(
      entitlementId: entitlement.identifier,
      productId: entitlement.productIdentifier,
      productPlanIdentifier: entitlement.productPlanIdentifier,
      store: _toBillingStore(entitlement.store),
      isActive: entitlement.isActive,
      willRenew: entitlement.willRenew,
      expiresAt: _parseDate(entitlement.expirationDate),
      unsubscribeDetectedAt: _parseDate(entitlement.unsubscribeDetectedAt),
      billingIssueDetectedAt: _parseDate(entitlement.billingIssueDetectedAt),
    );
  }

  BillingStore _toBillingStore(purchases.Store store) {
    return switch (store) {
      purchases.Store.appStore ||
      purchases.Store.macAppStore => BillingStore.appStore,
      purchases.Store.playStore => BillingStore.playStore,
      purchases.Store.testStore => BillingStore.testStore,
      _ => BillingStore.other,
    };
  }

  DateTime? _parseDate(String? value) {
    return value == null ? null : DateTime.tryParse(value);
  }
}

purchases.StoreReplacementMode? revenueCatStoreReplacementModeFor(
  BillingReplacementMode? mode,
) {
  return switch (mode) {
    BillingReplacementMode.withTimeProration =>
      purchases.StoreReplacementMode.withTimeProration,
    BillingReplacementMode.withoutProration =>
      purchases.StoreReplacementMode.withoutProration,
    BillingReplacementMode.deferred => purchases.StoreReplacementMode.deferred,
    null => null,
  };
}

class RevenueCatBillingRepository implements BillingRepository {
  RevenueCatBillingRepository({
    RevenueCatGateway? gateway,
    this.environment = RevenueCatEnvironment.fromEnvironment,
    RevenueCatPlatform? platform,
  }) : _gateway = gateway ?? PurchasesRevenueCatGateway(),
       _platform = platform;

  final RevenueCatGateway _gateway;
  final RevenueCatEnvironment environment;
  final RevenueCatPlatform? _platform;
  String? _currentAppUserId;

  @override
  Future<void> configure({required String? appUserId}) async {
    final platform = _platform ?? _currentPlatform();
    if (platform == null) {
      return;
    }

    final apiKey = environment.apiKeyFor(platform);
    if (apiKey == null) {
      return;
    }

    final normalizedAppUserId = _normalizeNullableAppUserId(appUserId);
    await _gateway.configure(apiKey: apiKey, appUserId: normalizedAppUserId);
    _currentAppUserId = normalizedAppUserId;
  }

  @override
  Future<List<BillingProduct>> fetchProducts() async {
    final packages = await _gateway.fetchPackages(
      RevenueCatCatalog.defaultOfferingId,
    );
    return packages
        .map(_toBillingProduct)
        .whereType<BillingProduct>()
        .toList(growable: false);
  }

  @override
  Future<BillingCustomerAccess> getCustomerAccess({
    bool forceRefresh = false,
  }) async {
    final snapshot = await _gateway.getCustomerInfo(forceRefresh: forceRefresh);
    return _toCustomerAccess(snapshot);
  }

  @override
  Future<void> identify(String appUserId) async {
    final normalizedAppUserId = appUserId.trim();
    if (normalizedAppUserId.isEmpty) {
      throw ArgumentError.value(appUserId, 'appUserId', '空文字は指定できません');
    }
    if (_currentAppUserId == normalizedAppUserId) {
      return;
    }

    await _gateway.logIn(normalizedAppUserId);
    _currentAppUserId = normalizedAppUserId;
  }

  @override
  Future<BillingPurchaseResult> purchase(BillingPurchaseRequest request) async {
    try {
      final platform = _platform ?? _currentPlatform();
      final isAndroid = platform == RevenueCatPlatform.android;
      final snapshot = await _gateway.purchase(
        RevenueCatPurchaseRequest(
          packageId: request.packageId,
          previousProductId: isAndroid ? request.previousProductId : null,
          replacementMode: isAndroid ? request.replacementMode : null,
        ),
      );
      return BillingPurchaseResult.purchased(_toCustomerAccess(snapshot));
    } on RevenueCatGatewayException catch (error) {
      return switch (error.failure) {
        RevenueCatGatewayFailure.cancelled =>
          const BillingPurchaseResult.cancelled(),
        RevenueCatGatewayFailure.failed => const BillingPurchaseResult.failed(),
      };
    }
  }

  @override
  Future<BillingCustomerAccess> restorePurchases() async {
    final snapshot = await _gateway.restorePurchases();
    return _toCustomerAccess(snapshot);
  }

  @override
  Stream<BillingCustomerAccess> watchCustomerAccess() {
    return _gateway.watchCustomerInfo().map(_toCustomerAccess);
  }

  BillingCustomerAccess _toCustomerAccess(RevenueCatCustomerSnapshot snapshot) {
    return BillingCustomerAccess(
      activeEntitlementIds: snapshot.activeEntitlementIds,
      activeSubscriptions: snapshot.activeSubscriptions
          .map(
            (subscription) => BillingSubscription.fromProduct(
              entitlementId: subscription.entitlementId,
              productId: subscription.productId,
              productPlanIdentifier: subscription.productPlanIdentifier,
              store: subscription.store,
              isActive: subscription.isActive,
              willRenew: subscription.willRenew,
              expiresAt: subscription.expiresAt,
              unsubscribeDetectedAt: subscription.unsubscribeDetectedAt,
              billingIssueDetectedAt: subscription.billingIssueDetectedAt,
            ),
          )
          .whereType<BillingSubscription>()
          .toList(growable: false),
      managementUrl: snapshot.managementUrl,
    );
  }

  BillingProduct? _toBillingProduct(RevenueCatPackageSnapshot package) {
    final productConfiguration = billingConfigurationForPackage(
      package.packageId,
    );
    if (productConfiguration == null) {
      return null;
    }

    return BillingProduct(
      packageId: package.packageId,
      productId: package.productId,
      tier: productConfiguration.tier,
      period: productConfiguration.period,
      title: package.title,
      priceText: package.priceText,
    );
  }

  String? _normalizeNullableAppUserId(String? appUserId) {
    final normalizedAppUserId = appUserId?.trim();
    if (normalizedAppUserId == null || normalizedAppUserId.isEmpty) {
      return null;
    }
    return normalizedAppUserId;
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
