import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/application/plan_access_controller.dart';
import 'package:physi_log/features/billing/domain/billing_customer_access.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_result.dart';
import 'package:physi_log/features/billing/domain/billing_repository.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/billing/domain/revenuecat_catalog.dart';

void main() {
  group('PlanAccessController', () {
    test('CustomerInfo更新で個人・家族からTeamを経てFreeへ遷移する', () async {
      final repository = _FakeBillingRepository(
        initialAccess: _access({RevenueCatCatalog.personalFamilyEntitlementId}),
        updates: Stream.fromIterable([
          _access({RevenueCatCatalog.teamEntitlementId}),
          _access(const {}),
        ]),
      );
      final controller = PlanAccessController(repository: repository);

      final states = await controller
          .watchAccess(
            hasLegacyPersonalFamily: false,
            hasLegacyTeam: false,
            hasManualTeam: false,
          )
          .take(3)
          .toList();

      expect(states.whereType<PlanAccessReady>().map((state) => state.tier), [
        PlanTier.personalFamily,
        PlanTier.team,
        PlanTier.free,
      ]);
    });

    test('RevenueCat取得失敗をFreeではなくerrorとして返す', () async {
      final repository = _FakeBillingRepository(
        initialAccess: _access(const {}),
        getError: StateError('network error'),
      );
      final controller = PlanAccessController(repository: repository);

      final state = await controller
          .watchAccess(
            hasLegacyPersonalFamily: false,
            hasLegacyTeam: false,
            hasManualTeam: false,
          )
          .first;

      expect(state, isA<PlanAccessError>());
    });

    test('RevenueCat権限がなくてもFirestoreの手動Team権限を合成する', () async {
      final repository = _FakeBillingRepository(
        initialAccess: _access(const {}),
      );
      final controller = PlanAccessController(repository: repository);

      final state = await controller
          .watchAccess(
            hasLegacyPersonalFamily: false,
            hasLegacyTeam: false,
            hasManualTeam: true,
          )
          .first;

      expect(state, isA<PlanAccessReady>());
      expect((state as PlanAccessReady).tier, PlanTier.team);
    });
  });
}

BillingCustomerAccess _access(Set<String> entitlementIds) {
  return BillingCustomerAccess(activeEntitlementIds: entitlementIds);
}

class _FakeBillingRepository implements BillingRepository {
  _FakeBillingRepository({
    required this.initialAccess,
    this.updates = const Stream.empty(),
    this.getError,
  });

  final BillingCustomerAccess initialAccess;
  final Stream<BillingCustomerAccess> updates;
  final Object? getError;

  @override
  Future<void> configure({required String? appUserId}) async {}

  @override
  Future<List<BillingProduct>> fetchProducts() async => const [];

  @override
  Future<BillingCustomerAccess> getCustomerAccess() async {
    final error = getError;
    if (error != null) {
      throw error;
    }
    return initialAccess;
  }

  @override
  Future<void> identify(String appUserId) async {}

  @override
  Future<BillingPurchaseResult> purchase(String packageId) async {
    return const BillingPurchaseResult.cancelled();
  }

  @override
  Future<BillingCustomerAccess> restorePurchases() async => initialAccess;

  @override
  Stream<BillingCustomerAccess> watchCustomerAccess() => updates;
}
