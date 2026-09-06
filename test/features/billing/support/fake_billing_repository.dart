import 'dart:async';

import 'package:physi_log/features/billing/domain/billing_customer_access.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_request.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_result.dart';
import 'package:physi_log/features/billing/domain/billing_repository.dart';
import 'package:physi_log/features/billing/domain/pending_subscription_change_repository.dart';

class FakeBillingRepository implements BillingRepository {
  FakeBillingRepository({
    this.products = const [],
    BillingPurchaseResult? purchaseResult,
    BillingCustomerAccess? restoreAccess,
    BillingCustomerAccess? currentAccess,
    this.customerAccessUpdates = const Stream.empty(),
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
  final Stream<BillingCustomerAccess> customerAccessUpdates;
  Object? fetchError;
  Object? customerAccessError;
  Object? purchaseError;
  Object? restoreError;
  Completer<BillingPurchaseResult>? purchaseCompleter;
  Completer<List<BillingProduct>>? fetchProductsCompleter;
  Completer<BillingCustomerAccess>? customerAccessCompleter;
  Completer<BillingCustomerAccess>? restoreCompleter;
  final purchaseRequests = <BillingPurchaseRequest>[];
  List<String> get purchasePackageIds {
    return purchaseRequests.map((request) => request.packageId).toList();
  }

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
    final error = customerAccessError;
    if (error != null) {
      throw error;
    }
    return customerAccessCompleter?.future ?? currentAccess;
  }

  @override
  Future<void> identify(String appUserId) async {}

  @override
  Future<BillingPurchaseResult> purchase(BillingPurchaseRequest request) async {
    purchaseRequests.add(request);
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
  Stream<BillingCustomerAccess> watchCustomerAccess() => customerAccessUpdates;
}

class FakePendingSubscriptionChangeRepository
    implements PendingSubscriptionChangeRepository {
  final changes = <String, PendingSubscriptionChange>{};
  final saveUserIds = <String>[];
  final deleteUserIds = <String>[];
  Object? getError;
  Object? saveError;
  Object? deleteError;

  @override
  Future<void> delete({required String userId}) async {
    final error = deleteError;
    if (error != null) {
      throw error;
    }
    deleteUserIds.add(userId);
    changes.remove(userId);
  }

  @override
  Future<PendingSubscriptionChange?> get({required String userId}) async {
    final error = getError;
    if (error != null) {
      throw error;
    }
    return changes[userId];
  }

  @override
  Future<void> save({
    required String userId,
    required PendingSubscriptionChange change,
  }) async {
    final error = saveError;
    if (error != null) {
      throw error;
    }
    saveUserIds.add(userId);
    changes[userId] = change;
  }
}
