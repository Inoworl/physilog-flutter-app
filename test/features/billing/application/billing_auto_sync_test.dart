import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/application/billing_controller.dart';
import 'package:physi_log/features/billing/domain/billing_customer_access.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_request.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_result.dart';
import 'package:physi_log/features/billing/domain/billing_subscription.dart';
import 'package:physi_log/features/billing/domain/pending_subscription_change_repository.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/revenuecat_catalog.dart';

import '../support/fake_billing_repository.dart';

void main() {
  test('起動時にキャッシュではなく最新の購入情報を取得する', () async {
    final repository = FakeBillingRepository();
    final controller = BillingController(repository: repository);
    addTearDown(controller.dispose);

    await controller.initialize(identitySync: Future.value());

    expect(repository.customerAccessRefreshes, [true]);
    expect(repository.restorePurchasesCalls, 0);
  });

  test('起動中の新しいSDK通知が処理中でも古い取得結果で初期化を失敗させない', () async {
    final updates = StreamController<BillingCustomerAccess>.broadcast();
    final pending = FakePendingSubscriptionChangeRepository()
      ..getCompleter = Completer<PendingSubscriptionChange?>();
    final repository = FakeBillingRepository(
      customerAccessUpdates: updates.stream,
    )..customerAccessCompleter = Completer<BillingCustomerAccess>();
    final controller = BillingController(
      repository: repository,
      pendingChangeRepository: pending,
      userId: 'test-user',
    );
    addTearDown(() {
      controller.dispose();
      unawaited(updates.close());
    });
    final initialization = controller.initialize(identitySync: Future.value());
    await Future<void>.delayed(Duration.zero);
    final purchased = _team(DateTime.utc(2026, 10, 11));
    updates.add(purchased);
    await Future<void>.delayed(Duration.zero);
    repository.customerAccessCompleter!.complete(_free);
    await initialization;
    pending.getCompleter!.complete(null);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.catalogStatus, BillingCatalogStatus.loaded);
    expect(controller.state.customerAccess, purchased);
  });

  testWidgets('期限到達時にサーバーの失効を取得してFreeへ戻す', (tester) async {
    final expiry = tester.binding.clock.now().add(const Duration(seconds: 20));
    final repository = FakeBillingRepository(currentAccess: _team(expiry));
    final controller = BillingController(
      repository: repository,
      now: tester.binding.clock.now,
    );
    addTearDown(controller.dispose);
    controller.setForeground(true);
    await controller.initialize(identitySync: Future.value());
    repository.currentAccess = _free;

    await tester.pump(const Duration(seconds: 19));
    expect(controller.state.customerAccess!.hasTeam, isTrue);
    await tester.pump(const Duration(seconds: 2));

    expect(controller.state.customerAccess!.hasTeam, isFalse);
    expect(repository.customerAccessRefreshes, [true, true]);
    expect(repository.restorePurchasesCalls, 0);
    controller.setForeground(false);
  });

  testWidgets('期限到達時に更新済みならTeamを維持する', (tester) async {
    final expiry = tester.binding.clock.now().add(const Duration(seconds: 20));
    final renewed = _team(expiry.add(const Duration(days: 30)));
    final repository = FakeBillingRepository(currentAccess: _team(expiry));
    final controller = BillingController(
      repository: repository,
      now: tester.binding.clock.now,
    );
    addTearDown(controller.dispose);
    controller.setForeground(true);
    await controller.initialize(identitySync: Future.value());
    repository.currentAccess = renewed;

    await tester.pump(const Duration(seconds: 21));

    expect(controller.state.customerAccess, renewed);
    controller.setForeground(false);
  });

  testWidgets('期限時の通信失敗でFreeにせず再試行で失効を反映する', (tester) async {
    final expiry = tester.binding.clock.now().add(const Duration(seconds: 10));
    final access = _team(expiry);
    final repository = FakeBillingRepository(currentAccess: access);
    final controller = BillingController(
      repository: repository,
      now: tester.binding.clock.now,
    );
    addTearDown(controller.dispose);
    controller.setForeground(true);
    await controller.initialize(identitySync: Future.value());
    repository.customerAccessError = StateError('offline');

    await tester.pump(const Duration(seconds: 11));
    expect(controller.state.customerAccess, access);
    repository.customerAccessError = null;
    repository.currentAccess = _free;
    await tester.pump(const Duration(seconds: 30));

    expect(controller.state.customerAccess, _free);
    expect(repository.restorePurchasesCalls, 0);
    controller.setForeground(false);
  });

  testWidgets('バックグラウンド中は通信せず復帰時に再取得する', (tester) async {
    final repository = FakeBillingRepository();
    final controller = BillingController(
      repository: repository,
      now: tester.binding.clock.now,
    );
    addTearDown(controller.dispose);
    controller.setForeground(true);
    await controller.initialize(identitySync: Future.value());
    controller.setForeground(false);
    await tester.pump(const Duration(minutes: 3));
    expect(repository.customerAccessRefreshes, [true]);

    repository.currentAccess = _team(
      tester.binding.clock.now().add(const Duration(days: 30)),
    );
    controller.setForeground(true);
    await tester.pump();

    expect(controller.state.customerAccess!.hasTeam, isTrue);
    expect(repository.customerAccessRefreshes, [true, true]);
    controller.setForeground(false);
  });

  testWidgets('画面を開いたままでも外部の購入変更を再確認する', (tester) async {
    final repository = FakeBillingRepository();
    final controller = BillingController(
      repository: repository,
      now: tester.binding.clock.now,
    );
    addTearDown(controller.dispose);
    controller.setForeground(true);
    await controller.initialize(identitySync: Future.value());
    repository.currentAccess = _team(
      tester.binding.clock.now().add(const Duration(days: 30)),
    );

    await tester.pump(const Duration(minutes: 1));

    expect(controller.state.customerAccess!.hasTeam, isTrue);
    expect(repository.restorePurchasesCalls, 0);
    controller.setForeground(false);
  });

  test('同時の再確認要求をまとめる', () async {
    final repository = FakeBillingRepository();
    final controller = BillingController(repository: repository);
    addTearDown(controller.dispose);
    await controller.initialize(identitySync: Future.value());
    repository.customerAccessCompleter = Completer<BillingCustomerAccess>();

    final first = controller.refreshCustomerAccess();
    final second = controller.refreshCustomerAccess();
    expect(repository.customerAccessRefreshes, [true, true]);
    repository.customerAccessCompleter!.complete(_free);
    await Future.wait([first, second]);
  });

  test('遅い再取得結果でSDKの新しい通知を上書きしない', () async {
    final updates = StreamController<BillingCustomerAccess>.broadcast();
    final repository = FakeBillingRepository(
      customerAccessUpdates: updates.stream,
    );
    final controller = BillingController(repository: repository);
    addTearDown(() {
      controller.dispose();
      unawaited(updates.close());
    });
    await controller.initialize(identitySync: Future.value());
    repository.customerAccessCompleter = Completer<BillingCustomerAccess>();
    final refresh = controller.refreshCustomerAccess();
    final purchased = _team(DateTime.utc(2026, 10, 11));
    updates.add(purchased);
    await Future<void>.delayed(Duration.zero);
    repository.customerAccessCompleter!.complete(_free);
    await refresh;

    expect(controller.state.customerAccess, purchased);
  });

  test('購入中に受けたSDK通知の遅い処理で購入成功を上書きしない', () async {
    final updates = StreamController<BillingCustomerAccess>.broadcast();
    final pending = FakePendingSubscriptionChangeRepository();
    final repository = FakeBillingRepository(
      customerAccessUpdates: updates.stream,
    );
    final controller = BillingController(
      repository: repository,
      pendingChangeRepository: pending,
      userId: 'test-user',
    );
    addTearDown(() {
      controller.dispose();
      unawaited(updates.close());
    });
    await controller.initialize(identitySync: Future.value());
    repository.purchaseCompleter = Completer<BillingPurchaseResult>();
    final purchase = controller.purchase(_purchaseRequest);
    pending.getCompleter = Completer<PendingSubscriptionChange?>();
    updates
      ..add(_free)
      ..add(_free);
    await Future<void>.delayed(Duration.zero);
    final purchased = _team(DateTime.utc(2026, 10, 11));
    repository.purchaseCompleter!.complete(
      BillingPurchaseResult.purchased(purchased),
    );
    await purchase;
    pending.getCompleter!.complete(null);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.customerAccess, purchased);
  });

  testWidgets('破棄後にタイマーや再取得結果を反映しない', (tester) async {
    final repository = FakeBillingRepository();
    final controller = BillingController(
      repository: repository,
      now: tester.binding.clock.now,
    );
    controller.setForeground(true);
    await controller.initialize(identitySync: Future.value());
    repository.customerAccessCompleter = Completer<BillingCustomerAccess>();
    final refresh = controller.refreshCustomerAccess();
    controller.dispose();
    repository.customerAccessCompleter!.complete(_free);
    await refresh;
    await tester.pump(const Duration(minutes: 3));

    expect(repository.customerAccessRefreshes, [true, true]);
  });

  for (final restore in [false, true]) {
    test('遅い再取得結果で${restore ? '復元' : '購入'}成功を上書きしない', () async {
      final purchased = _team(DateTime.utc(2026, 10, 11));
      final repository = FakeBillingRepository(
        purchaseResult: BillingPurchaseResult.purchased(purchased),
        restoreAccess: purchased,
      );
      final controller = BillingController(repository: repository);
      addTearDown(controller.dispose);
      await controller.initialize(identitySync: Future.value());
      repository.customerAccessCompleter = Completer<BillingCustomerAccess>();
      final refresh = controller.refreshCustomerAccess();
      if (restore) {
        await controller.restorePurchases();
      } else {
        await controller.purchase(_purchaseRequest);
      }
      repository.customerAccessCompleter!.complete(_free);
      await refresh;
      expect(controller.state.customerAccess, purchased);
    });
  }

  testWidgets('購入中は再確認せず購入例外の後も自動同期を続ける', (tester) async {
    final repository = FakeBillingRepository();
    final controller = BillingController(
      repository: repository,
      now: tester.binding.clock.now,
    );
    addTearDown(controller.dispose);
    controller.setForeground(true);
    await controller.initialize(identitySync: Future.value());
    repository.purchaseCompleter = Completer<BillingPurchaseResult>();
    final purchase = controller.purchase(_purchaseRequest);
    await tester.pump(const Duration(minutes: 2));
    expect(repository.customerAccessRefreshes, [true]);
    repository.purchaseCompleter!.completeError(StateError('purchase-failed'));
    await purchase;
    repository.currentAccess = _team(
      tester.binding.clock.now().add(const Duration(days: 30)),
    );
    await tester.pump(const Duration(minutes: 1));
    expect(controller.state.customerAccess!.hasTeam, isTrue);
    controller.setForeground(false);
  });
}

const _purchaseRequest = BillingPurchaseRequest(
  packageId: 'team_monthly',
  productId: 'team_monthly',
  changeType: SubscriptionChangeType.newPurchase,
  timing: SubscriptionChangeTiming.immediate,
);

final _free = BillingCustomerAccess(activeEntitlementIds: const {});

BillingCustomerAccess _team(DateTime expiresAt) => BillingCustomerAccess(
  activeEntitlementIds: {RevenueCatCatalog.teamEntitlementId},
  activeSubscriptions: [
    BillingSubscription(
      entitlementId: RevenueCatCatalog.teamEntitlementId,
      productId: RevenueCatCatalog.teamMonthlyProductId,
      tier: PlanTier.team,
      period: BillingPeriod.monthly,
      store: BillingStore.appStore,
      isActive: true,
      willRenew: false,
      expiresAt: expiresAt,
    ),
  ],
);
