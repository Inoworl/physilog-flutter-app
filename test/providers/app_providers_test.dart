import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/application/billing_controller.dart';
import 'package:physi_log/features/billing/data/revenuecat_billing_repository.dart';
import 'package:physi_log/features/billing/domain/billing_customer_access.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_request.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_result.dart';
import 'package:physi_log/features/billing/domain/billing_repository.dart';
import 'package:physi_log/features/billing/domain/pending_subscription_change_repository.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/billing/domain/revenuecat_catalog.dart';
import 'package:physi_log/features/entitlements/domain/entitlement_repository.dart';
import 'package:physi_log/models/entitlement.dart';
import 'package:physi_log/providers/app_providers.dart';

void main() {
  test('currentUserIdProviderは未認証時にlocal-userを返す', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final userId = container.read(currentUserIdProvider);
    expect(userId, 'local-user');
  });

  test('useFirestoreProviderはmodeがfirestoreかつ認証済みならtrueを返す', () {
    final container = ProviderContainer(
      overrides: [
        dataStoreModeProvider.overrideWithValue(DataStoreMode.firestore),
        currentUserIdProvider.overrideWithValue('firebase-user-id'),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(useFirestoreProvider), isTrue);
  });

  test('useFirestoreProviderはlocal-user時にfalseを返す', () {
    final container = ProviderContainer(
      overrides: [
        dataStoreModeProvider.overrideWithValue(DataStoreMode.firestore),
        currentUserIdProvider.overrideWithValue('local-user'),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(useFirestoreProvider), isFalse);
  });

  test('localモードでは課金SDKを呼ばずFreeのready状態を返す', () async {
    final repository = _FakeBillingRepository();
    final container = ProviderContainer(
      overrides: [billingRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final state = await container.read(planAccessStateStreamProvider.future);

    expect(state, isA<PlanAccessReady>());
    expect((state as PlanAccessReady).tier, PlanTier.free);
    expect(repository.identityCalls, isEmpty);
    expect(repository.getCustomerAccessCalls, 0);
  });

  test('localモードではRevenueCatのRepositoryを選択しない', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(billingRepositoryProvider),
      isNot(isA<RevenueCatBillingRepository>()),
    );
  });

  test('firestoreモードではUIDを同期してRevenueCatのTeam権限を返す', () async {
    final repository = _FakeBillingRepository(
      customerAccess: BillingCustomerAccess(
        activeEntitlementIds: {RevenueCatCatalog.teamEntitlementId},
      ),
    );
    final container = ProviderContainer(
      overrides: [
        dataStoreModeProvider.overrideWithValue(DataStoreMode.firestore),
        currentUserIdProvider.overrideWithValue('firebase-user-id'),
        billingRepositoryProvider.overrideWithValue(repository),
        entitlementRepositoryProvider.overrideWithValue(
          const _FakeEntitlementRepository(null),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(planAccessStateStreamProvider.future);

    expect(state, isA<PlanAccessReady>());
    expect((state as PlanAccessReady).tier, PlanTier.team);
    expect(repository.identityCalls, ['configure:firebase-user-id']);
  });

  test('プラン取得中はFreeではなくloading状態を返す', () {
    final repository = _FakeBillingRepository(
      customerAccessCompleter: Completer<BillingCustomerAccess>(),
    );
    final container = ProviderContainer(
      overrides: [
        dataStoreModeProvider.overrideWithValue(DataStoreMode.firestore),
        currentUserIdProvider.overrideWithValue('firebase-user-id'),
        billingRepositoryProvider.overrideWithValue(repository),
        entitlementRepositoryProvider.overrideWithValue(
          const _FakeEntitlementRepository(null),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(planAccessStateProvider), isA<PlanAccessLoading>());
  });

  test('RevenueCat取得失敗はFreeではなくerror状態を返す', () async {
    final repository = _FakeBillingRepository(
      getError: StateError('network error'),
    );
    final container = ProviderContainer(
      overrides: [
        dataStoreModeProvider.overrideWithValue(DataStoreMode.firestore),
        currentUserIdProvider.overrideWithValue('firebase-user-id'),
        billingRepositoryProvider.overrideWithValue(repository),
        entitlementRepositoryProvider.overrideWithValue(
          const _FakeEntitlementRepository(null),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(planAccessStateStreamProvider.future);

    expect(state, isA<PlanAccessError>());
  });

  test('currentUserIdProvider変更でRevenueCat identityを再同期する', () async {
    final testUserIdProvider = StateProvider<String?>((ref) => 'anonymous-a');
    final repository = _FakeBillingRepository();
    final container = ProviderContainer(
      overrides: [
        dataStoreModeProvider.overrideWithValue(DataStoreMode.firestore),
        currentUserIdProvider.overrideWith(
          (ref) => ref.watch(testUserIdProvider),
        ),
        billingRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(billingIdentitySyncProvider.future);
    container.read(testUserIdProvider.notifier).state = 'email-b';
    await container.read(billingIdentitySyncProvider.future);
    container.read(testUserIdProvider.notifier).state = 'anonymous-c';
    await container.read(billingIdentitySyncProvider.future);

    expect(repository.identityCalls, [
      'configure:anonymous-a',
      'identify:email-b',
      'identify:anonymous-c',
    ]);
  });

  test('billingControllerProviderはUID同期完了後に商品を取得する', () async {
    final configureCompleter = Completer<void>();
    final repository = _FakeBillingRepository(
      configureCompleter: configureCompleter,
    );
    final container = ProviderContainer(
      overrides: [
        dataStoreModeProvider.overrideWithValue(DataStoreMode.firestore),
        currentUserIdProvider.overrideWithValue('firebase-user-id'),
        billingRepositoryProvider.overrideWithValue(repository),
        pendingSubscriptionChangeRepositoryProvider.overrideWithValue(
          const NoPendingSubscriptionChangeRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen<BillingState>(
      billingControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);

    expect(repository.fetchProductsCalls, 0);

    configureCompleter.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(repository.fetchProductsCalls, 1);
  });

  test('据え置き個人・家族entitlementをRevenueCat権限と合成する', () async {
    final now = DateTime(2026, 5, 27, 10);
    final container = ProviderContainer(
      overrides: [
        dataStoreModeProvider.overrideWithValue(DataStoreMode.firestore),
        currentUserIdProvider.overrideWithValue('firebase-user-id'),
        billingRepositoryProvider.overrideWithValue(_FakeBillingRepository()),
        entitlementRepositoryProvider.overrideWithValue(
          _FakeEntitlementRepository(
            Entitlement(
              id: 'current',
              userId: 'firebase-user-id',
              plan: EntitlementPlans.legacyPersonalFamily,
              source: EntitlementSources.manual,
              status: EntitlementStatuses.active,
              grantedAt: now,
              updatedAt: now,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(planAccessStateStreamProvider.future);

    expect(state, isA<PlanAccessReady>());
    expect((state as PlanAccessReady).tier, PlanTier.personalFamily);
  });
}

class _FakeBillingRepository implements BillingRepository {
  _FakeBillingRepository({
    BillingCustomerAccess? customerAccess,
    this.customerAccessCompleter,
    this.configureCompleter,
    this.getError,
  }) : customerAccess =
           customerAccess ??
           BillingCustomerAccess(activeEntitlementIds: const {});

  final BillingCustomerAccess customerAccess;
  final Completer<BillingCustomerAccess>? customerAccessCompleter;
  final Completer<void>? configureCompleter;
  final Object? getError;
  final identityCalls = <String>[];
  var getCustomerAccessCalls = 0;
  var fetchProductsCalls = 0;

  @override
  Future<void> configure({required String? appUserId}) async {
    identityCalls.add('configure:$appUserId');
    await configureCompleter?.future;
  }

  @override
  Future<List<BillingProduct>> fetchProducts() async {
    fetchProductsCalls++;
    return const [];
  }

  @override
  Future<BillingCustomerAccess> getCustomerAccess({
    bool forceRefresh = false,
  }) async {
    getCustomerAccessCalls++;
    final error = getError;
    if (error != null) {
      throw error;
    }
    return customerAccessCompleter?.future ?? customerAccess;
  }

  @override
  Future<void> identify(String appUserId) async {
    identityCalls.add('identify:$appUserId');
  }

  @override
  Future<BillingPurchaseResult> purchase(BillingPurchaseRequest request) async {
    return const BillingPurchaseResult.cancelled();
  }

  @override
  Future<BillingCustomerAccess> restorePurchases() async => customerAccess;

  @override
  Stream<BillingCustomerAccess> watchCustomerAccess() => const Stream.empty();
}

class _FakeEntitlementRepository implements EntitlementRepository {
  const _FakeEntitlementRepository(this.entitlement);

  final Entitlement? entitlement;

  @override
  Stream<Entitlement?> watchCurrentEntitlement({required String userId}) =>
      Stream.value(entitlement);

  @override
  Future<Entitlement?> getCurrentEntitlement({required String userId}) async {
    return entitlement;
  }
}
