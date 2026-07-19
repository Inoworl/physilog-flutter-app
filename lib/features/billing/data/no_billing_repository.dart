import '../domain/billing_customer_access.dart';
import '../domain/billing_product.dart';
import '../domain/billing_purchase_result.dart';
import '../domain/billing_repository.dart';

/// RevenueCatを利用しない環境で安全な空状態を返すRepository。
class NoBillingRepository implements BillingRepository {
  const NoBillingRepository();

  BillingCustomerAccess get _noAccess {
    return BillingCustomerAccess(activeEntitlementIds: const {});
  }

  @override
  Future<void> configure({required String? appUserId}) async {}

  @override
  Future<List<BillingProduct>> fetchProducts() async => const [];

  @override
  Future<BillingCustomerAccess> getCustomerAccess() async => _noAccess;

  @override
  Future<void> identify(String appUserId) async {}

  @override
  Future<BillingPurchaseResult> purchase(String packageId) async {
    return const BillingPurchaseResult.failed();
  }

  @override
  Future<BillingCustomerAccess> restorePurchases() async => _noAccess;

  @override
  Stream<BillingCustomerAccess> watchCustomerAccess() {
    return Stream.value(_noAccess);
  }
}
