import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/application/billing_identity_sync.dart';
import 'package:physi_log/features/billing/domain/billing_customer_access.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_request.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_result.dart';
import 'package:physi_log/features/billing/domain/billing_repository.dart';

void main() {
  test('初回UIDをconfigureし以後の異なるUIDだけをidentifyする', () async {
    final repository = _RecordingBillingRepository();
    final sync = BillingIdentitySync(repository: repository);

    await sync.synchronize(' anonymous-a ');
    await sync.synchronize('anonymous-a');
    await sync.synchronize('email-b');
    await sync.synchronize('email-b');
    await sync.synchronize('anonymous-c');

    expect(repository.identityCalls, [
      'configure:anonymous-a',
      'identify:email-b',
      'identify:anonymous-c',
    ]);
  });

  test('nullまたは空のUIDではRepositoryを呼ばない', () async {
    final repository = _RecordingBillingRepository();
    final sync = BillingIdentitySync(repository: repository);

    await sync.synchronize(null);
    await sync.synchronize('   ');

    expect(repository.identityCalls, isEmpty);
  });

  test('初回configure中にUIDが変わっても順番に同期する', () async {
    final configureCompleter = Completer<void>();
    final repository = _RecordingBillingRepository(
      configureCompleter: configureCompleter,
    );
    final sync = BillingIdentitySync(repository: repository);

    final firstSync = sync.synchronize('anonymous-a');
    await Future<void>.delayed(Duration.zero);
    final secondSync = sync.synchronize('email-b');
    await Future<void>.delayed(Duration.zero);

    expect(repository.identityCalls, ['configure:anonymous-a']);

    configureCompleter.complete();
    await Future.wait([firstSync, secondSync]);

    expect(repository.identityCalls, [
      'configure:anonymous-a',
      'identify:email-b',
    ]);
  });
}

class _RecordingBillingRepository implements BillingRepository {
  _RecordingBillingRepository({this.configureCompleter});

  final Completer<void>? configureCompleter;
  final identityCalls = <String>[];

  @override
  Future<void> configure({required String? appUserId}) async {
    identityCalls.add('configure:$appUserId');
    await configureCompleter?.future;
  }

  @override
  Future<List<BillingProduct>> fetchProducts() async => const [];

  @override
  Future<BillingCustomerAccess> getCustomerAccess() async {
    return BillingCustomerAccess(activeEntitlementIds: const {});
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
  Future<BillingCustomerAccess> restorePurchases() async {
    return BillingCustomerAccess(activeEntitlementIds: const {});
  }

  @override
  Stream<BillingCustomerAccess> watchCustomerAccess() => const Stream.empty();
}
