import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/application/billing_controller.dart';
import 'package:physi_log/features/billing/domain/billing_catalog_failure.dart';
import 'package:physi_log/features/billing/domain/billing_customer_access.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_result.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/revenuecat_catalog.dart';

import '../support/fake_billing_repository.dart';

void main() {
  group('BillingController', () {
    test('商品を読み込みloaded状態へ遷移する', () async {
      final repository = FakeBillingRepository(products: [_personalProduct]);
      final controller = BillingController(repository: repository);
      addTearDown(controller.dispose);

      await controller.loadProducts();

      expect(controller.state.catalogStatus, BillingCatalogStatus.loaded);
      expect(controller.state.products, [_personalProduct]);
      expect(repository.fetchProductsCalls, 1);
    });

    test('商品がなくてもloaded状態として空一覧を保持する', () async {
      final controller = BillingController(repository: FakeBillingRepository());
      addTearDown(controller.dispose);

      await controller.loadProducts();

      expect(controller.state.catalogStatus, BillingCatalogStatus.loaded);
      expect(controller.state.products, isEmpty);
    });

    test('UID同期完了まで商品取得を開始しない', () async {
      final identitySyncCompleter = Completer<void>();
      final repository = FakeBillingRepository(products: [_personalProduct]);
      final controller = BillingController(repository: repository);
      addTearDown(controller.dispose);

      final initialization = controller.initialize(
        identitySync: identitySyncCompleter.future,
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.catalogStatus, BillingCatalogStatus.loading);
      expect(controller.state.isIdentitySynchronized, isFalse);
      expect(repository.fetchProductsCalls, 0);

      identitySyncCompleter.complete();
      await initialization;

      expect(repository.fetchProductsCalls, 1);
      expect(controller.state.catalogStatus, BillingCatalogStatus.loaded);
      expect(controller.state.isIdentitySynchronized, isTrue);
    });

    test('UID同期失敗を安全な分類で保持する', () async {
      final controller = BillingController(repository: FakeBillingRepository());
      addTearDown(controller.dispose);

      await controller.initialize(
        identitySync: Future<void>.error(
          const BillingCatalogException(
            BillingCatalogFailure.invalidCredentials,
          ),
        ),
      );

      expect(controller.state.catalogStatus, BillingCatalogStatus.failed);
      expect(controller.state.isIdentitySynchronized, isFalse);
      expect(
        controller.state.catalogFailure,
        BillingCatalogFailure.invalidCredentials,
      );
    });

    test('商品取得例外をfailed状態へ変換する', () async {
      final repository = FakeBillingRepository()
        ..fetchError = StateError('network error');
      final controller = BillingController(repository: repository);
      addTearDown(controller.dispose);

      await controller.loadProducts();

      expect(controller.state.catalogStatus, BillingCatalogStatus.failed);
      expect(controller.state.products, isEmpty);
      expect(controller.state.catalogFailure, BillingCatalogFailure.unknown);
    });

    test('RevenueCat商品取得失敗の分類を状態へ引き継ぐ', () async {
      final repository = FakeBillingRepository()
        ..fetchError = const BillingCatalogException(
          BillingCatalogFailure.network,
        );
      final controller = BillingController(repository: repository);
      addTearDown(controller.dispose);

      await controller.loadProducts();

      expect(controller.state.catalogStatus, BillingCatalogStatus.failed);
      expect(controller.state.catalogFailure, BillingCatalogFailure.network);
    });

    test('商品取得中に破棄されても完了後に状態を書き込まない', () async {
      final completer = Completer<List<BillingProduct>>();
      final repository = FakeBillingRepository()
        ..fetchProductsCompleter = completer;
      final controller = BillingController(repository: repository);

      final loading = controller.loadProducts();
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      completer.complete([_personalProduct]);

      await expectLater(loading, completes);
    });

    test('購入成功時にaccessを通知して成功状態へ遷移する', () async {
      final access = BillingCustomerAccess(
        activeEntitlementIds: {RevenueCatCatalog.personalFamilyEntitlementId},
      );
      final repository = FakeBillingRepository(
        purchaseResult: BillingPurchaseResult.purchased(access),
      );
      BillingCustomerAccess? notifiedAccess;
      final controller = BillingController(
        repository: repository,
        onCustomerAccessChanged: (access) => notifiedAccess = access,
      );
      addTearDown(controller.dispose);

      await controller.purchase(_personalProduct.packageId);

      expect(
        controller.state.actionStatus,
        BillingActionStatus.purchaseSucceeded,
      );
      expect(notifiedAccess, access);
      expect(repository.purchasePackageIds, [_personalProduct.packageId]);
    });

    test('購入キャンセルと購入失敗を異なる状態へ変換する', () async {
      final repository = FakeBillingRepository();
      final controller = BillingController(repository: repository);
      addTearDown(controller.dispose);

      repository.purchaseResult = const BillingPurchaseResult.cancelled();
      await controller.purchase(_personalProduct.packageId);
      expect(
        controller.state.actionStatus,
        BillingActionStatus.purchaseCancelled,
      );

      repository.purchaseResult = const BillingPurchaseResult.failed();
      await controller.purchase(_personalProduct.packageId);
      expect(controller.state.actionStatus, BillingActionStatus.purchaseFailed);
    });

    test('購入処理中の再呼び出しを無視して二重購入を防ぐ', () async {
      final completer = Completer<BillingPurchaseResult>();
      final repository = FakeBillingRepository()..purchaseCompleter = completer;
      final controller = BillingController(repository: repository);
      addTearDown(controller.dispose);

      final firstPurchase = controller.purchase(_personalProduct.packageId);
      await Future<void>.delayed(Duration.zero);
      final secondPurchase = controller.purchase(_personalProduct.packageId);

      expect(repository.purchasePackageIds, [_personalProduct.packageId]);
      expect(controller.state.actionStatus, BillingActionStatus.purchasing);

      completer.complete(const BillingPurchaseResult.cancelled());
      await Future.wait([firstPurchase, secondPurchase]);
    });

    test('購入例外を購入失敗へ変換する', () async {
      final repository = FakeBillingRepository()
        ..purchaseError = StateError('purchase error');
      final controller = BillingController(repository: repository);
      addTearDown(controller.dispose);

      await controller.purchase(_personalProduct.packageId);

      expect(controller.state.actionStatus, BillingActionStatus.purchaseFailed);
    });

    test('購入中に破棄されても完了後に状態とaccessを通知しない', () async {
      final completer = Completer<BillingPurchaseResult>();
      final access = BillingCustomerAccess(
        activeEntitlementIds: {RevenueCatCatalog.personalFamilyEntitlementId},
      );
      final repository = FakeBillingRepository()..purchaseCompleter = completer;
      var notificationCount = 0;
      final controller = BillingController(
        repository: repository,
        onCustomerAccessChanged: (_) => notificationCount++,
      );

      final purchasing = controller.purchase(_personalProduct.packageId);
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      completer.complete(BillingPurchaseResult.purchased(access));

      await expectLater(purchasing, completes);
      expect(notificationCount, 0);
    });

    test('復元成功時にaccessを通知して成功状態へ遷移する', () async {
      final access = BillingCustomerAccess(
        activeEntitlementIds: {RevenueCatCatalog.teamEntitlementId},
      );
      final repository = FakeBillingRepository(restoreAccess: access);
      BillingCustomerAccess? notifiedAccess;
      final controller = BillingController(
        repository: repository,
        onCustomerAccessChanged: (access) => notifiedAccess = access,
      );
      addTearDown(controller.dispose);

      await controller.restorePurchases();

      expect(
        controller.state.actionStatus,
        BillingActionStatus.restoreSucceeded,
      );
      expect(notifiedAccess, access);
      expect(repository.restorePurchasesCalls, 1);
    });

    test('復元例外を復元失敗へ変換する', () async {
      final repository = FakeBillingRepository()
        ..restoreError = StateError('restore error');
      final controller = BillingController(repository: repository);
      addTearDown(controller.dispose);

      await controller.restorePurchases();

      expect(controller.state.actionStatus, BillingActionStatus.restoreFailed);
    });

    test('復元中に破棄されても完了後に状態とaccessを通知しない', () async {
      final completer = Completer<BillingCustomerAccess>();
      final access = BillingCustomerAccess(
        activeEntitlementIds: {RevenueCatCatalog.teamEntitlementId},
      );
      final repository = FakeBillingRepository()..restoreCompleter = completer;
      var notificationCount = 0;
      final controller = BillingController(
        repository: repository,
        onCustomerAccessChanged: (_) => notificationCount++,
      );

      final restoring = controller.restorePurchases();
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      completer.complete(access);

      await expectLater(restoring, completes);
      expect(notificationCount, 0);
    });
  });
}

const _personalProduct = BillingProduct(
  packageId: r'$rc_monthly',
  productId: RevenueCatCatalog.personalFamilyMonthlyProductId,
  tier: PlanTier.personalFamily,
  period: BillingPeriod.monthly,
  title: '個人・家族 月額',
  priceText: '¥500',
);
