import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/data/revenuecat_billing_repository.dart';
import 'package:physi_log/features/billing/domain/billing_catalog_failure.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_request.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_result.dart';
import 'package:physi_log/features/billing/domain/billing_subscription.dart';
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
          packageId: RevenueCatCatalog.personalFamilyMonthlyPackageId,
          productId: RevenueCatCatalog.personalFamilyMonthlyProductId,
          title: '個人・家族 月額',
          priceText: '¥500',
        ),
        RevenueCatPackageSnapshot(
          packageId: RevenueCatCatalog.teamYearlyPackageId,
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
          packageId: RevenueCatCatalog.personalFamilyMonthlyPackageId,
          productId: RevenueCatCatalog.personalFamilyMonthlyProductId,
          tier: PlanTier.personalFamily,
          period: BillingPeriod.monthly,
          title: '個人・家族 月額',
          priceText: '¥500',
        ),
        const BillingProduct(
          packageId: RevenueCatCatalog.teamYearlyPackageId,
          productId: RevenueCatCatalog.teamYearlyProductId,
          tier: PlanTier.team,
          period: BillingPeriod.yearly,
          title: 'Team 年額',
          priceText: '¥9,800',
        ),
      ]);
    });

    test('platform固有商品IDを共通Package IDでドメインモデルへ変換する', () async {
      gateway.packages = const [
        RevenueCatPackageSnapshot(
          packageId: 'personal_family_monthly',
          productId: 'com.inoworl.physilog.personal_family.monthly',
          title: '個人・家族 月額',
          priceText: '¥500',
        ),
        RevenueCatPackageSnapshot(
          packageId: 'team_yearly',
          productId: 'team:yearly',
          title: 'Team 年額',
          priceText: '¥9,800',
        ),
      ];

      final products = await repository.fetchProducts();

      expect(products.map((product) => product.productId), [
        'com.inoworl.physilog.personal_family.monthly',
        'team:yearly',
      ]);
      expect(products.map((product) => (product.tier, product.period)), [
        (PlanTier.personalFamily, BillingPeriod.monthly),
        (PlanTier.team, BillingPeriod.yearly),
      ]);
    });

    test('購入成功を更新後の顧客アクセスへ変換する', () async {
      gateway.purchaseAccess = const RevenueCatCustomerSnapshot(
        activeEntitlementIds: {RevenueCatCatalog.personalFamilyEntitlementId},
      );

      final result = await repository.purchase(_newPurchaseRequest);

      expect(result.status, BillingPurchaseStatus.purchased);
      expect(result.customerAccess?.hasPersonalFamily, isTrue);
      expect(gateway.purchaseCalls.single.packageId, r'$rc_monthly');
    });

    test('ユーザーキャンセルとその他の購入失敗を区別する', () async {
      gateway.purchaseError = const RevenueCatGatewayException.cancelled();

      final cancelled = await repository.purchase(_newPurchaseRequest);

      gateway.purchaseError = const RevenueCatGatewayException.failed();
      final failed = await repository.purchase(_newPurchaseRequest);

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

    test('CustomerInfoの契約詳細と管理URLをドメインへ変換する', () async {
      gateway.currentAccess = RevenueCatCustomerSnapshot(
        activeEntitlementIds: const {
          RevenueCatCatalog.personalFamilyEntitlementId,
          RevenueCatCatalog.teamEntitlementId,
        },
        activeSubscriptions: [
          RevenueCatEntitlementSnapshot(
            entitlementId: RevenueCatCatalog.personalFamilyEntitlementId,
            productId: 'com.inoworl.physilog.personal_family.monthly',
            store: BillingStore.appStore,
            isActive: true,
            willRenew: true,
            expiresAt: DateTime.utc(2026, 8, 1),
          ),
          RevenueCatEntitlementSnapshot(
            entitlementId: RevenueCatCatalog.teamEntitlementId,
            productId: 'team',
            productPlanIdentifier: 'yearly',
            store: BillingStore.playStore,
            isActive: true,
            willRenew: false,
            expiresAt: DateTime.utc(2027, 1, 1),
            unsubscribeDetectedAt: DateTime.utc(2026, 7, 1),
            billingIssueDetectedAt: DateTime.utc(2026, 7, 2),
          ),
        ],
        managementUrl: 'https://play.google.com/store/account/subscriptions',
      );

      final access = await repository.getCustomerAccess();

      final current = access.currentSubscription;
      expect(current?.tier, PlanTier.team);
      expect(current?.period, BillingPeriod.yearly);
      expect(current?.productId, 'team:yearly');
      expect(current?.store, BillingStore.playStore);
      expect(current?.willRenew, isFalse);
      expect(current?.isCancellationScheduled, isTrue);
      expect(current?.hasBillingIssue, isTrue);
      expect(current?.expiresAt, DateTime.utc(2027, 1, 1));
      expect(
        access.managementUri,
        Uri.parse('https://play.google.com/store/account/subscriptions'),
      );
    });

    test('Androidの変更購入へ旧商品IDとReplacement Modeを渡す', () async {
      repository = RevenueCatBillingRepository(
        gateway: gateway,
        environment: const RevenueCatEnvironment(
          iosApiKey: 'ios-public-sdk-key',
          androidApiKey: 'android-public-sdk-key',
        ),
        platform: RevenueCatPlatform.android,
      );

      await repository.purchase(_upgradeRequest);

      final request = gateway.purchaseCalls.single;
      expect(
        request.previousProductId,
        RevenueCatCatalog.personalFamilyMonthlyProductId,
      );
      expect(request.replacementMode, BillingReplacementMode.withTimeProration);
    });

    test('iOSの変更購入はStoreKitへ委ねAndroid固有情報を渡さない', () async {
      await repository.purchase(_upgradeRequest);

      final request = gateway.purchaseCalls.single;
      expect(request.previousProductId, isNull);
      expect(request.replacementMode, isNull);
    });

    test('Replacement ModeをRevenueCat SDK型へ明示変換する', () {
      expect(
        revenueCatStoreReplacementModeFor(
          BillingReplacementMode.withTimeProration,
        ),
        purchases.StoreReplacementMode.withTimeProration,
      );
      expect(
        revenueCatStoreReplacementModeFor(
          BillingReplacementMode.withoutProration,
        ),
        purchases.StoreReplacementMode.withoutProration,
      );
      expect(
        revenueCatStoreReplacementModeFor(BillingReplacementMode.deferred),
        purchases.StoreReplacementMode.deferred,
      );
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
  final purchaseCalls = <RevenueCatPurchaseRequest>[];
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
  Future<RevenueCatCustomerSnapshot> purchase(
    RevenueCatPurchaseRequest request,
  ) async {
    purchaseCalls.add(request);
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

const _newPurchaseRequest = BillingPurchaseRequest(
  packageId: r'$rc_monthly',
  productId: RevenueCatCatalog.personalFamilyMonthlyProductId,
  changeType: SubscriptionChangeType.newPurchase,
  timing: SubscriptionChangeTiming.immediate,
);

const _upgradeRequest = BillingPurchaseRequest(
  packageId: 'team_monthly',
  productId: RevenueCatCatalog.teamMonthlyProductId,
  previousProductId: RevenueCatCatalog.personalFamilyMonthlyProductId,
  changeType: SubscriptionChangeType.upgrade,
  timing: SubscriptionChangeTiming.immediate,
  replacementMode: BillingReplacementMode.withTimeProration,
);

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
