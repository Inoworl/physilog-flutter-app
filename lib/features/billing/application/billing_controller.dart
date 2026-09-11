import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/billing_catalog_failure.dart';
import '../domain/billing_customer_access.dart';
import '../domain/billing_product.dart';
import '../domain/billing_purchase_request.dart';
import '../domain/billing_purchase_result.dart';
import '../domain/billing_repository.dart';
import '../domain/billing_subscription.dart';
import '../domain/pending_subscription_change_repository.dart';

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
    this.customerAccess,
    this.pendingChange,
  });

  final BillingCatalogStatus catalogStatus;
  final List<BillingProduct> products;
  final BillingActionStatus actionStatus;
  final String? activePackageId;
  final BillingCatalogFailure? catalogFailure;
  final bool isIdentitySynchronized;
  final BillingCustomerAccess? customerAccess;
  final PendingSubscriptionChange? pendingChange;

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
    Object? customerAccess = _notProvided,
    Object? pendingChange = _notProvided,
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
      customerAccess: identical(customerAccess, _notProvided)
          ? this.customerAccess
          : customerAccess as BillingCustomerAccess?,
      pendingChange: identical(pendingChange, _notProvided)
          ? this.pendingChange
          : pendingChange as PendingSubscriptionChange?,
    );
  }

  static const _notProvided = Object();
}

class BillingController extends StateNotifier<BillingState> {
  BillingController({
    required BillingRepository repository,
    void Function(BillingCustomerAccess access)? onCustomerAccessChanged,
    PendingSubscriptionChangeRepository? pendingChangeRepository,
    String? userId,
    DateTime Function()? now,
  }) : _repository = repository,
       _onCustomerAccessChanged = onCustomerAccessChanged,
       _pendingChangeRepository =
           pendingChangeRepository ??
           const NoPendingSubscriptionChangeRepository(),
       _userId = userId,
       _now = now ?? DateTime.now,
       super(const BillingState());

  final BillingRepository _repository;
  final void Function(BillingCustomerAccess access)? _onCustomerAccessChanged;
  final PendingSubscriptionChangeRepository _pendingChangeRepository;
  final String? _userId;
  final DateTime Function() _now;
  StreamSubscription<BillingCustomerAccess>? _customerAccessSubscription;
  Timer? _refreshTimer;
  Future<bool>? _refreshInFlight;
  var _isForeground = false;
  var _customerAccessRevision = 0;

  void setForeground(bool isForeground) {
    if (!mounted || _isForeground == isForeground) return;
    _isForeground = isForeground;
    _refreshTimer?.cancel();
    if (isForeground) {
      unawaited(refreshCustomerAccess());
    }
  }

  Future<bool> refreshCustomerAccess() {
    return _refreshCustomerAccess(notifyAccessChanged: true);
  }

  Future<bool> _refreshCustomerAccess({required bool notifyAccessChanged}) {
    if (!mounted || !state.isIdentitySynchronized || state.isActionInProgress) {
      return Future.value(false);
    }
    return _refreshInFlight ??=
        _fetchCustomerAccess(
          notifyAccessChanged: notifyAccessChanged,
        ).whenComplete(() {
          _refreshInFlight = null;
          _scheduleNextRefresh();
        });
  }

  Future<bool> _fetchCustomerAccess({required bool notifyAccessChanged}) async {
    final revision = _customerAccessRevision;
    try {
      final access = await _repository.getCustomerAccess(forceRefresh: true);
      if (!mounted) return false;
      if (revision == _customerAccessRevision && !state.isActionInProgress) {
        await _applyCustomerAccess(
          access,
          notifyAccessChanged: notifyAccessChanged,
        );
      }
      return mounted;
    } on Object {
      return false;
    }
  }

  void _scheduleNextRefresh() {
    _refreshTimer?.cancel();
    if (!mounted ||
        !_isForeground ||
        !state.isIdentitySynchronized ||
        state.isActionInProgress ||
        _refreshInFlight != null) {
      return;
    }
    var delay = const Duration(minutes: 1);
    final now = _now();
    for (final subscription
        in state.customerAccess?.activeSubscriptions ??
            const <BillingSubscription>[]) {
      final expiresAt = subscription.expiresAt;
      if (!subscription.isActive || expiresAt == null) continue;
      final untilExpiry = expiresAt.difference(now);
      final nextCheck = untilExpiry <= Duration.zero
          ? const Duration(seconds: 30)
          : untilExpiry + const Duration(seconds: 1);
      if (nextCheck < delay) delay = nextCheck;
    }
    _refreshTimer = Timer(delay, () {
      unawaited(refreshCustomerAccess());
    });
  }

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
    _watchCustomerAccess();
    final customerAccessLoaded = await _loadCustomerAccess();
    if (!mounted) {
      return;
    }
    if (!customerAccessLoaded) {
      const failure = BillingCatalogFailure.unknown;
      _debugFailure('customer-access', failure);
      state = state.copyWith(
        catalogStatus: BillingCatalogStatus.failed,
        products: const [],
        catalogFailure: failure,
      );
      return;
    }
    await loadProducts();
    if (!mounted) {
      return;
    }
  }

  Future<bool> _loadCustomerAccess() {
    return _refreshCustomerAccess(notifyAccessChanged: false);
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

  void _debugPendingChangeFailure(String operation) {
    assert(() {
      debugPrint('Billing pending subscription change $operation failed');
      return true;
    }());
  }

  Future<void> purchase(BillingPurchaseRequest request) async {
    if (state.isActionInProgress) {
      return;
    }

    _customerAccessRevision++;

    state = state.copyWith(
      actionStatus: BillingActionStatus.purchasing,
      activePackageId: request.packageId,
    );
    _scheduleNextRefresh();

    BillingPurchaseResult result;
    try {
      result = await _repository.purchase(request);
    } on Object {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        actionStatus: BillingActionStatus.purchaseFailed,
        activePackageId: null,
      );
      _scheduleNextRefresh();
      return;
    }

    if (!mounted) {
      return;
    }

    switch (result.status) {
      case BillingPurchaseStatus.purchased:
        final customerAccess = result.customerAccess;
        final pendingChange = customerAccess == null
            ? state.pendingChange
            : await _pendingChangeAfterPurchase(request, customerAccess);
        if (!mounted) {
          return;
        }
        _customerAccessRevision++;
        state = state.copyWith(
          actionStatus: BillingActionStatus.purchaseSucceeded,
          activePackageId: null,
          customerAccess: customerAccess,
          pendingChange: pendingChange,
        );
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
    _scheduleNextRefresh();
  }

  Future<void> restorePurchases() async {
    if (state.isActionInProgress) {
      return;
    }

    _customerAccessRevision++;

    state = state.copyWith(
      actionStatus: BillingActionStatus.restoring,
      activePackageId: null,
    );
    _scheduleNextRefresh();
    try {
      final customerAccess = await _repository.restorePurchases();
      final pendingChange = await _loadPendingChange(customerAccess);
      if (!mounted) {
        return;
      }
      _customerAccessRevision++;
      state = state.copyWith(
        actionStatus: BillingActionStatus.restoreSucceeded,
        customerAccess: customerAccess,
        pendingChange: pendingChange,
      );
      _onCustomerAccessChanged?.call(customerAccess);
    } on Object {
      if (!mounted) {
        return;
      }
      state = state.copyWith(actionStatus: BillingActionStatus.restoreFailed);
    }
    _scheduleNextRefresh();
  }

  Future<PendingSubscriptionChange?> _loadPendingChange(
    BillingCustomerAccess customerAccess,
  ) async {
    final userId = _userId;
    if (userId == null) {
      return null;
    }

    PendingSubscriptionChange? pendingChange;
    try {
      pendingChange = await _pendingChangeRepository.get(userId: userId);
    } on Object {
      _debugPendingChangeFailure('load');
      return state.pendingChange;
    }
    if (pendingChange == null) {
      return null;
    }
    if (customerAccess.currentSubscription?.productId !=
        pendingChange.targetProductId) {
      return pendingChange;
    }

    try {
      await _pendingChangeRepository.delete(userId: userId);
    } on Object {
      _debugPendingChangeFailure('delete');
    }
    return null;
  }

  Future<PendingSubscriptionChange?> _pendingChangeAfterPurchase(
    BillingPurchaseRequest request,
    BillingCustomerAccess customerAccess,
  ) async {
    final userId = _userId;
    if (userId == null) {
      return state.pendingChange;
    }

    if (customerAccess.currentSubscription?.productId == request.productId) {
      try {
        await _pendingChangeRepository.delete(userId: userId);
      } on Object {
        _debugPendingChangeFailure('delete');
      }
      return null;
    }

    final previousProductId = request.previousProductId;
    if (!request.isScheduledForNextRenewal || previousProductId == null) {
      return state.pendingChange;
    }

    final pendingChange = PendingSubscriptionChange(
      previousProductId: previousProductId,
      targetProductId: request.productId,
      createdAt: _now(),
    );
    try {
      await _pendingChangeRepository.save(
        userId: userId,
        change: pendingChange,
      );
    } on Object {
      _debugPendingChangeFailure('save');
    }
    return pendingChange;
  }

  void _watchCustomerAccess() {
    unawaited(_customerAccessSubscription?.cancel());
    _customerAccessSubscription = _repository.watchCustomerAccess().listen(
      (customerAccess) async {
        try {
          await _applyCustomerAccess(customerAccess, notifyAccessChanged: true);
        } on Object {
          _debugPendingChangeFailure('customer-info-stream');
        }
      },
      onError: (Object _) {
        _debugPendingChangeFailure('customer-info-stream');
      },
    );
  }

  Future<void> _applyCustomerAccess(
    BillingCustomerAccess customerAccess, {
    required bool notifyAccessChanged,
  }) async {
    final revision = ++_customerAccessRevision;
    final pendingChange = await _loadPendingChange(customerAccess);
    if (!mounted || revision != _customerAccessRevision) {
      return;
    }
    final changed = state.customerAccess != customerAccess;
    state = state.copyWith(
      customerAccess: customerAccess,
      pendingChange: pendingChange,
    );
    if (notifyAccessChanged && changed) {
      _onCustomerAccessChanged?.call(customerAccess);
    }
    _scheduleNextRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _customerAccessRevision++;
    unawaited(_customerAccessSubscription?.cancel());
    super.dispose();
  }
}
