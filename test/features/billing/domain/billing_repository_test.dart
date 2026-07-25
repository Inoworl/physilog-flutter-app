import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/domain/billing_customer_access.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_request.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_result.dart';
import 'package:physi_log/features/billing/domain/billing_repository.dart';

void main() {
  test('SDKなしのFakeでBillingRepositoryを実装できる', () {
    expect(_FakeBillingRepository(), isA<BillingRepository>());
  });
}

class _FakeBillingRepository implements BillingRepository {
  @override
  Future<void> configure({required String? appUserId}) async {}

  @override
  Future<List<BillingProduct>> fetchProducts() async => const [];

  @override
  Future<BillingCustomerAccess> getCustomerAccess() async {
    return BillingCustomerAccess(activeEntitlementIds: const {});
  }

  @override
  Future<void> identify(String appUserId) async {}

  @override
  Future<BillingPurchaseResult> purchase(BillingPurchaseRequest request) async {
    return const BillingPurchaseResult.cancelled();
  }

  @override
  Future<BillingCustomerAccess> restorePurchases() async {
    return BillingCustomerAccess(activeEntitlementIds: const {});
  }

  @override
  Stream<BillingCustomerAccess> watchCustomerAccess() => const Stream.empty();
}
