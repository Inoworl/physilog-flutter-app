import 'dart:async';

import 'package:physi_log/features/billing/domain/billing_customer_access.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_result.dart';
import 'package:physi_log/features/billing/domain/billing_repository.dart';

class FakeBillingRepository implements BillingRepository {
  FakeBillingRepository({
    this.products = const [],
    BillingPurchaseResult? purchaseResult,
    BillingCustomerAccess? restoreAccess,
    BillingCustomerAccess? currentAccess,
  }) : purchaseResult =
           purchaseResult ?? const BillingPurchaseResult.cancelled(),
       restoreAccess =
           restoreAccess ??
           BillingCustomerAccess(activeEntitlementIds: const {}),
       currentAccess =
           currentAccess ??
           BillingCustomerAccess(activeEntitlementIds: const {});

  List<BillingProduct> products;
  BillingPurchaseResult purchaseResult;
  BillingCustomerAccess restoreAccess;
  BillingCustomerAccess currentAccess;
  Object? fetchError;
  Object? purchaseError;
  Object? restoreError;
  Completer<BillingPurchaseResult>? purchaseCompleter;
  Completer<List<BillingProduct>>? fetchProductsCompleter;
  Completer<BillingCustomerAccess>? restoreCompleter;
  final purchasePackageIds = <String>[];
  var fetchProductsCalls = 0;
  var restorePurchasesCalls = 0;

  @override
  Future<void> configure({required String? appUserId}) async {}

  @override
  Future<List<BillingProduct>> fetchProducts() async {
    fetchProductsCalls++;
    final error = fetchError;
    if (error != null) {
      throw error;
    }
    return fetchProductsCompleter?.future ?? products;
  }

  @override
  Future<BillingCustomerAccess> getCustomerAccess() async {
    return currentAccess;
  }

  @override
  Future<void> identify(String appUserId) async {}

  @override
  Future<BillingPurchaseResult> purchase(String packageId) async {
    purchasePackageIds.add(packageId);
    final error = purchaseError;
    if (error != null) {
      throw error;
    }
    final result =
        await (purchaseCompleter?.future ?? Future.value(purchaseResult));
    final access = result.customerAccess;
    if (access != null) {
      currentAccess = access;
    }
    return result;
  }

  @override
  Future<BillingCustomerAccess> restorePurchases() async {
    restorePurchasesCalls++;
    final error = restoreError;
    if (error != null) {
      throw error;
    }
    final access =
        await (restoreCompleter?.future ?? Future.value(restoreAccess));
    currentAccess = access;
    return access;
  }

  @override
  Stream<BillingCustomerAccess> watchCustomerAccess() => const Stream.empty();
}
