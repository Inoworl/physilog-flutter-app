import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/billing_catalog_failure.dart';
import '../domain/billing_customer_access.dart';
import '../domain/billing_product.dart';
import '../domain/billing_purchase_result.dart';
import '../domain/billing_repository.dart';

enum BillingCatalogStatus { initial, loading, loaded, failed }

enum BillingActionStatus {
  idle,
  purchasing,
  purchaseSucceeded,
  purchaseCancelled,
  purchaseFailed,
  restoring,
  restoreSucceeded,
  restoreFailed,
}

class BillingState {
  const BillingState({
    this.catalogStatus = BillingCatalogStatus.initial,
    this.products = const [],
    this.actionStatus = BillingActionStatus.idle,
    this.activePackageId,
    this.catalogFailure,
    this.isIdentitySynchronized = false,
  });

  final BillingCatalogStatus catalogStatus;
  final List<BillingProduct> products;
  final BillingActionStatus actionStatus;
  final String? activePackageId;
  final BillingCatalogFailure? catalogFailure;
  final bool isIdentitySynchronized;

  bool get isActionInProgress {
    return actionStatus == BillingActionStatus.purchasing ||
        actionStatus == BillingActionStatus.restoring;
  }

  BillingState copyWith({
    BillingCatalogStatus? catalogStatus,
    List<BillingProduct>? products,
    BillingActionStatus? actionStatus,
    Object? activePackageId = _notProvided,
    Object? catalogFailure = _notProvided,
    bool? isIdentitySynchronized,
  }) {
    return BillingState(
      catalogStatus: catalogStatus ?? this.catalogStatus,
      products: products ?? this.products,
      actionStatus: actionStatus ?? this.actionStatus,
      activePackageId: identical(activePackageId, _notProvided)
          ? this.activePackageId
          : activePackageId as String?,
      catalogFailure: identical(catalogFailure, _notProvided)
          ? this.catalogFailure
          : catalogFailure as BillingCatalogFailure?,
      isIdentitySynchronized:
          isIdentitySynchronized ?? this.isIdentitySynchronized,
    );
  }

  static const _notProvided = Object();
}

class BillingController extends StateNotifier<BillingState> {
  BillingController({
    required BillingRepository repository,
    void Function(BillingCustomerAccess access)? onCustomerAccessChanged,
  }) : _repository = repository,
       _onCustomerAccessChanged = onCustomerAccessChanged,
       super(const BillingState());

  final BillingRepository _repository;
  final void Function(BillingCustomerAccess access)? _onCustomerAccessChanged;

  Future<void> initialize({required Future<void> identitySync}) async {
    state = state.copyWith(
      catalogStatus: BillingCatalogStatus.loading,
      catalogFailure: null,
      isIdentitySynchronized: false,
    );
    try {
      await identitySync;
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final failure = _failureFor(error);
      _debugFailure('identity-sync', failure);
      state = state.copyWith(
        catalogStatus: BillingCatalogStatus.failed,
        products: const [],
        catalogFailure: failure,
      );
      return;
    }

    if (!mounted) {
      return;
    }
    state = state.copyWith(isIdentitySynchronized: true);
    await loadProducts();
  }

  Future<void> loadProducts() async {
    state = state.copyWith(
      catalogStatus: BillingCatalogStatus.loading,
      catalogFailure: null,
    );
    try {
      final products = await _repository.fetchProducts();
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        catalogStatus: BillingCatalogStatus.loaded,
        products: List.unmodifiable(products),
        catalogFailure: null,
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final failure = _failureFor(error);
      _debugFailure('product-fetch', failure);
      state = state.copyWith(
        catalogStatus: BillingCatalogStatus.failed,
        products: const [],
        catalogFailure: failure,
      );
    }
  }

  BillingCatalogFailure _failureFor(Object error) {
    if (error is BillingCatalogException) {
      return error.failure;
    }
    return BillingCatalogFailure.unknown;
  }

  void _debugFailure(String operation, BillingCatalogFailure failure) {
    assert(() {
      debugPrint('Billing catalog $operation failed: ${failure.name}');
      return true;
    }());
  }

  Future<void> purchase(String packageId) async {
    if (state.isActionInProgress) {
      return;
    }

    state = state.copyWith(
      actionStatus: BillingActionStatus.purchasing,
      activePackageId: packageId,
    );

    BillingPurchaseResult result;
    try {
      result = await _repository.purchase(packageId);
    } on Object {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        actionStatus: BillingActionStatus.purchaseFailed,
        activePackageId: null,
      );
      return;
    }

    if (!mounted) {
      return;
    }

    switch (result.status) {
      case BillingPurchaseStatus.purchased:
        state = state.copyWith(
          actionStatus: BillingActionStatus.purchaseSucceeded,
          activePackageId: null,
        );
        final customerAccess = result.customerAccess;
        if (customerAccess != null) {
          _onCustomerAccessChanged?.call(customerAccess);
        }
      case BillingPurchaseStatus.cancelled:
        state = state.copyWith(
          actionStatus: BillingActionStatus.purchaseCancelled,
          activePackageId: null,
        );
      case BillingPurchaseStatus.failed:
        state = state.copyWith(
          actionStatus: BillingActionStatus.purchaseFailed,
          activePackageId: null,
        );
    }
  }

  Future<void> restorePurchases() async {
    if (state.isActionInProgress) {
      return;
    }

    state = state.copyWith(
      actionStatus: BillingActionStatus.restoring,
      activePackageId: null,
    );
    try {
      final customerAccess = await _repository.restorePurchases();
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        actionStatus: BillingActionStatus.restoreSucceeded,
      );
      _onCustomerAccessChanged?.call(customerAccess);
    } on Object {
      if (!mounted) {
        return;
      }
      state = state.copyWith(actionStatus: BillingActionStatus.restoreFailed);
    }
  }
}
