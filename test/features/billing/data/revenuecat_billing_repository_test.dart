import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/data/revenuecat_billing_repository.dart';
import 'package:physi_log/features/billing/domain/billing_catalog_failure.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_result.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/revenuecat_catalog.dart';
import 'package:physi_log/features/billing/domain/revenuecat_environment.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as purchases;

void main() {
  group('RevenueCatエラー分類', () {
    test('SDK例外を秘密値を含まない分類へ変換する', () {
      BillingCatalogFailure classify(purchases.PurchasesErrorCode code) {
        return revenueCatCatalogFailureFor(
          PlatformException(code: code.index.toString()),
        );
      }

      expect(
        classify(purchases.PurchasesErrorCode.invalidCredentialsError),
        BillingCatalogFailure.invalidCredentials,
      );
      expect(
        classify(purchases.PurchasesErrorCode.configurationError),
        BillingCatalogFailure.configuration,
      );
      expect(
        classify(purchases.PurchasesErrorCode.networkError),
        BillingCatalogFailure.network,
      );
      expect(
        classify(purchases.PurchasesErrorCode.offlineConnectionError),
        BillingCatalogFailure.offline,
      );
      expect(
        classify(purchases.PurchasesErrorCode.apiEndpointBlocked),
        BillingCatalogFailure.endpointBlocked,
      );
    });

    test('configuration例外の既知メッセージを設定不整合別に分類する', () {
      BillingCatalogFailure classify(String message) {
        return revenueCatCatalogFailureFor(
          PlatformException(
            code: purchases.PurchasesErrorCode.configurationError.index
                .toString(),
            message: message,
          ),
        );
      }

      expect(
        classify(
          'You have configured the SDK with a Test Store API key, but there '
          'are no Test Store products registered in the RevenueCat dashboard '
          'for your offerings.',
        ),
        BillingCatalogFailure.noTestStoreProducts,
      );
      expect(
        classify(
          'No packages could be found for offering with identifier default.',
        ),
        BillingCatalogFailure.offeringEmpty,
      );
      expect(
        classify(
          'None of the products registered in the RevenueCat dashboard could '
          'be fetched from App Store Connect.',
        ),
        BillingCatalogFailure.productsUnavailable,
      );
    });
  });

  group('PurchasesRevenueCatGateway.configure', () {
    late _FakeRevenueCatSetupClient setupClient;
    late PurchasesRevenueCatGateway gateway;

    setUp(() {
      setupClient = _FakeRevenueCatSetupClient();
      gateway = PurchasesRevenueCatGateway(setupClient: setupClient);
    });

    test('SDK未設定ならAPIキーとUIDでconfigureする', () async {
      await gateway.configure(apiKey: 'public-sdk-key', appUserId: 'user-1');

      expect(setupClient.configureCalls, [
        const _ConfigureCall(apiKey: 'public-sdk-key', appUserId: 'user-1'),
      ]);
      expect(setupClient.logInCalls, isEmpty);
    });

    test('SDK設定済みでUIDが同じなら何もしない', () async {
      setupClient
        ..configured = true
        ..currentAppUserId = 'user-1';

      await gateway.configure(apiKey: 'public-sdk-key', appUserId: 'user-1');

      expect(setupClient.configureCalls, isEmpty);
      expect(setupClient.logInCalls, isEmpty);
    });

    test('SDK設定済みでUIDが異なるならlogInする', () async {
      setupClient
        ..configured = true
        ..currentAppUserId = 'user-before-hot-restart';

      await gateway.configure(apiKey: 'public-sdk-key', appUserId: 'user-1');

      expect(setupClient.configureCalls, isEmpty);
      expect(setupClient.logInCalls, ['user-1']);
    });

    test('SDK設定済みでUID未確定なら既存ユーザーを維持する', () async {
      setupClient
        ..configured = true
        ..currentAppUserId = 'existing-user';

      await gateway.configure(apiKey: 'public-sdk-key', appUserId: null);

      expect(setupClient.configureCalls, isEmpty);
      expect(setupClient.logInCalls, isEmpty);
      expect(setupClient.appUserIdReadCount, 0);
    });
  });

  group('RevenueCatBillingRepository', () {
    late _FakeRevenueCatGateway gateway;
    late RevenueCatBillingRepository repository;

    setUp(() {
      gateway = _FakeRevenueCatGateway();
      repository = RevenueCatBillingRepository(
        gateway: gateway,
        environment: const RevenueCatEnvironment(
          iosApiKey: 'ios-public-sdk-key',
          androidApiKey: 'android-public-sdk-key',
        ),
        platform: RevenueCatPlatform.ios,
      );
    });

    tearDown(() async {
      await gateway.dispose();
    });

    test('設定時に対象プラットフォームのキーと正規化したUIDを渡す', () async {
      await repository.configure(appUserId: ' user-1 ');

      expect(gateway.configureCalls, [
        const _ConfigureCall(apiKey: 'ios-public-sdk-key', appUserId: 'user-1'),
      ]);
    });

    test('同じUIDへのidentifyを重複して実行しない', () async {
      await repository.configure(appUserId: 'user-1');

      await repository.identify('user-2');
      await repository.identify('user-2');

      expect(gateway.logInCalls, ['user-2']);
    });

    test('default Offeringの対応商品だけをドメインモデルへ変換する', () async {
      gateway.packages = const [
        RevenueCatPackageSnapshot(
          packageId: r'$rc_monthly',
          productId: RevenueCatCatalog.personalFamilyMonthlyProductId,
          title: '個人・家族 月額',
          priceText: '¥500',
        ),
        RevenueCatPackageSnapshot(
          packageId: r'$rc_annual',
          productId: RevenueCatCatalog.teamYearlyProductId,
          title: 'Team 年額',
          priceText: '¥9,800',
        ),
        RevenueCatPackageSnapshot(
          packageId: 'unsupported',
          productId: 'unsupported_product',
          title: '対象外',
          priceText: '¥100',
        ),
      ];

      final products = await repository.fetchProducts();

      expect(gateway.requestedOfferingIds, [
        RevenueCatCatalog.defaultOfferingId,
      ]);
      expect(products, [
        const BillingProduct(
          packageId: r'$rc_monthly',
          productId: RevenueCatCatalog.personalFamilyMonthlyProductId,
          tier: PlanTier.personalFamily,
          period: BillingPeriod.monthly,
          title: '個人・家族 月額',
          priceText: '¥500',
        ),
        const BillingProduct(
          packageId: r'$rc_annual',
          productId: RevenueCatCatalog.teamYearlyProductId,
          tier: PlanTier.team,
          period: BillingPeriod.yearly,
          title: 'Team 年額',
          priceText: '¥9,800',
        ),
      ]);
    });

    test('購入成功を更新後の顧客アクセスへ変換する', () async {
      gateway.purchaseAccess = const RevenueCatCustomerSnapshot(
        activeEntitlementIds: {RevenueCatCatalog.personalFamilyEntitlementId},
      );

      final result = await repository.purchase(r'$rc_monthly');

      expect(result.status, BillingPurchaseStatus.purchased);
      expect(result.customerAccess?.hasPersonalFamily, isTrue);
      expect(gateway.purchaseCalls, [r'$rc_monthly']);
    });

    test('ユーザーキャンセルとその他の購入失敗を区別する', () async {
      gateway.purchaseError = const RevenueCatGatewayException.cancelled();

      final cancelled = await repository.purchase(r'$rc_monthly');

      gateway.purchaseError = const RevenueCatGatewayException.failed();
      final failed = await repository.purchase(r'$rc_monthly');

      expect(cancelled.status, BillingPurchaseStatus.cancelled);
      expect(failed.status, BillingPurchaseStatus.failed);
    });

    test('復元・現在値・更新streamを顧客アクセスへ変換する', () async {
      gateway.restoreAccess = const RevenueCatCustomerSnapshot(
        activeEntitlementIds: {RevenueCatCatalog.teamEntitlementId},
      );
      gateway.currentAccess = const RevenueCatCustomerSnapshot(
        activeEntitlementIds: {RevenueCatCatalog.personalFamilyEntitlementId},
      );

      final restored = await repository.restorePurchases();
      final current = await repository.getCustomerAccess();
      final updatedFuture = repository.watchCustomerAccess().first;
      gateway.customerInfoController.add(
        const RevenueCatCustomerSnapshot(
          activeEntitlementIds: {RevenueCatCatalog.teamEntitlementId},
        ),
      );
      final updated = await updatedFuture;

      expect(restored.hasTeam, isTrue);
      expect(current.hasPersonalFamily, isTrue);
      expect(updated.hasTeam, isTrue);
    });
  });
}

class _FakeRevenueCatSetupClient implements RevenueCatSetupClient {
  bool configured = false;
  String currentAppUserId = 'existing-user';
  var appUserIdReadCount = 0;
  final configureCalls = <_ConfigureCall>[];
  final logInCalls = <String>[];

  @override
  Future<String> get appUserId async {
    appUserIdReadCount++;
    return currentAppUserId;
  }

  @override
  Future<void> configure({
    required String apiKey,
    required String? appUserId,
  }) async {
    configureCalls.add(_ConfigureCall(apiKey: apiKey, appUserId: appUserId));
  }

  @override
  Future<bool> get isConfigured async => configured;

  @override
  Future<void> logIn(String appUserId) async {
    logInCalls.add(appUserId);
    currentAppUserId = appUserId;
  }
}

class _FakeRevenueCatGateway implements RevenueCatGateway {
  final configureCalls = <_ConfigureCall>[];
  final logInCalls = <String>[];
  final requestedOfferingIds = <String>[];
  final purchaseCalls = <String>[];
  final customerInfoController =
      StreamController<RevenueCatCustomerSnapshot>.broadcast();

  List<RevenueCatPackageSnapshot> packages = const [];
  RevenueCatCustomerSnapshot purchaseAccess = const RevenueCatCustomerSnapshot(
    activeEntitlementIds: {},
  );
  RevenueCatCustomerSnapshot restoreAccess = const RevenueCatCustomerSnapshot(
    activeEntitlementIds: {},
  );
  RevenueCatCustomerSnapshot currentAccess = const RevenueCatCustomerSnapshot(
    activeEntitlementIds: {},
  );
  RevenueCatGatewayException? purchaseError;

  @override
  Future<void> configure({
    required String apiKey,
    required String? appUserId,
  }) async {
    configureCalls.add(_ConfigureCall(apiKey: apiKey, appUserId: appUserId));
  }

  Future<void> dispose() => customerInfoController.close();

  @override
  Future<List<RevenueCatPackageSnapshot>> fetchPackages(
    String offeringId,
  ) async {
    requestedOfferingIds.add(offeringId);
    return packages;
  }

  @override
  Future<RevenueCatCustomerSnapshot> getCustomerInfo() async => currentAccess;

  @override
  Future<void> logIn(String appUserId) async {
    logInCalls.add(appUserId);
  }

  @override
  Future<RevenueCatCustomerSnapshot> purchase(String packageId) async {
    purchaseCalls.add(packageId);
    final error = purchaseError;
    if (error != null) {
      throw error;
    }
    return purchaseAccess;
  }

  @override
  Future<RevenueCatCustomerSnapshot> restorePurchases() async => restoreAccess;

  @override
  Stream<RevenueCatCustomerSnapshot> watchCustomerInfo() {
    return customerInfoController.stream;
  }
}

class _ConfigureCall {
  const _ConfigureCall({required this.apiKey, required this.appUserId});

  final String apiKey;
  final String? appUserId;

  @override
  bool operator ==(Object other) {
    return other is _ConfigureCall &&
        other.apiKey == apiKey &&
        other.appUserId == appUserId;
  }

  @override
  int get hashCode => Object.hash(apiKey, appUserId);
}
