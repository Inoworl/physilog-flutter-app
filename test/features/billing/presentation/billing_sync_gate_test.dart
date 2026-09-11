import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/domain/billing_customer_access.dart';
import 'package:physi_log/features/billing/domain/pending_subscription_change_repository.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/billing/domain/revenuecat_catalog.dart';
import 'package:physi_log/features/billing/presentation/billing_sync_gate.dart';
import 'package:physi_log/features/entitlements/data/no_entitlement_repository.dart';
import 'package:physi_log/providers/app_providers.dart';

import '../support/fake_billing_repository.dart';

void main() {
  testWidgets('プラン画面以外でも復帰時に購入情報を自動同期する', (tester) async {
    final repository = FakeBillingRepository();
    final container = ProviderContainer(
      overrides: [
        useFirestoreProvider.overrideWithValue(true),
        currentUserIdProvider.overrideWithValue('test-user'),
        billingIdentitySyncProvider.overrideWith((ref) async {}),
        billingRepositoryProvider.overrideWithValue(repository),
        billingClockProvider.overrideWithValue(tester.binding.clock.now),
        pendingSubscriptionChangeRepositoryProvider.overrideWithValue(
          const NoPendingSubscriptionChangeRepository(),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BillingSyncGate(child: Text('Home'))),
      ),
    );
    await tester.pumpAndSettle();
    final initialRequests = repository.customerAccessRefreshes.length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    expect(repository.customerAccessRefreshes.length, initialRequests);

    repository.currentAccess = BillingCustomerAccess(
      activeEntitlementIds: {RevenueCatCatalog.teamEntitlementId},
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(
      container.read(billingControllerProvider).customerAccess!.hasTeam,
      isTrue,
    );
    expect(repository.customerAccessRefreshes.length, initialRequests + 1);
    expect(repository.restorePurchasesCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(minutes: 2));
    expect(repository.customerAccessRefreshes.length, initialRequests + 1);
  });

  testWidgets('ローカルモードでは購入情報へアクセスしない', (tester) async {
    final repository = FakeBillingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          useFirestoreProvider.overrideWithValue(false),
          billingRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: BillingSyncGate(child: Text('Local'))),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(minutes: 2));
    expect(repository.customerAccessRefreshes, isEmpty);
    expect(repository.fetchProductsCalls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('自動再取得をプランに反映しアカウント切替後の遅い応答を捨てる', (tester) async {
    final userProvider = StateProvider<String?>((ref) => 'first-user');
    final repository = FakeBillingRepository();
    final container = ProviderContainer(
      overrides: [
        dataStoreModeProvider.overrideWithValue(DataStoreMode.firestore),
        currentUserIdProvider.overrideWith((ref) => ref.watch(userProvider)),
        billingIdentitySyncProvider.overrideWith((ref) async {}),
        billingRepositoryProvider.overrideWithValue(repository),
        billingClockProvider.overrideWithValue(tester.binding.clock.now),
        entitlementRepositoryProvider.overrideWithValue(
          const NoEntitlementRepository(),
        ),
        pendingSubscriptionChangeRepositoryProvider.overrideWithValue(
          const NoPendingSubscriptionChangeRepository(),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: BillingSyncGate(
          child: Consumer(
            builder: (context, ref, child) {
              ref.watch(planAccessStateProvider);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      (container.read(planAccessStateProvider) as PlanAccessReady).tier,
      PlanTier.free,
    );
    final teamAccess = BillingCustomerAccess(
      activeEntitlementIds: {RevenueCatCatalog.teamEntitlementId},
    );
    repository.currentAccess = teamAccess;
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(
      (container.read(planAccessStateProvider) as PlanAccessReady).tier,
      PlanTier.team,
    );

    final oldController = container.read(billingControllerProvider.notifier);
    final oldResponse = Completer<BillingCustomerAccess>();
    repository.customerAccessCompleter = oldResponse;
    final oldRefresh = oldController.refreshCustomerAccess();
    repository.customerAccessCompleter = null;
    repository.currentAccess = BillingCustomerAccess(
      activeEntitlementIds: const {},
    );
    container.read(userProvider.notifier).state = 'second-user';
    await tester.pumpAndSettle();
    expect(
      container.read(billingControllerProvider.notifier),
      isNot(same(oldController)),
    );
    expect(
      (container.read(planAccessStateProvider) as PlanAccessReady).tier,
      PlanTier.free,
    );
    oldResponse.complete(teamAccess);
    await oldRefresh;
    await tester.pumpAndSettle();
    expect(
      container.read(billingControllerProvider).customerAccess!.hasTeam,
      isFalse,
    );
    expect(
      (container.read(planAccessStateProvider) as PlanAccessReady).tier,
      PlanTier.free,
    );

    container.read(userProvider.notifier).state = null;
    await tester.pumpAndSettle();
    final requestCount = repository.customerAccessRefreshes.length;
    await tester.pump(const Duration(minutes: 2));
    expect(repository.customerAccessRefreshes.length, requestCount);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}
