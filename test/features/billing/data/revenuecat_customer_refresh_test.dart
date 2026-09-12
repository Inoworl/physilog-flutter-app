import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/data/revenuecat_billing_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('purchases_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('強制取得はSDKキャッシュの無効化完了後にCustomerInfoを取得する', () async {
    final methods = <String>[];
    final invalidated = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      if (call.method == 'invalidateCustomerInfoCache') {
        await invalidated.future;
        return null;
      }
      return _emptyCustomerInfo;
    });
    final result = PurchasesRevenueCatGateway().getCustomerInfo(
      forceRefresh: true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(methods, ['invalidateCustomerInfoCache']);
    invalidated.complete();
    expect((await result).activeEntitlementIds, isEmpty);
    expect(methods, ['invalidateCustomerInfoCache', 'getCustomerInfo']);
  });

  test('通常取得はSDKキャッシュを無効化しない', () async {
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return _emptyCustomerInfo;
    });
    await PurchasesRevenueCatGateway().getCustomerInfo();
    expect(methods, ['getCustomerInfo']);
  });

  test('キャッシュ無効化失敗を成功やFreeとして返さない', () async {
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      throw PlatformException(code: 'offline');
    });
    await expectLater(
      PurchasesRevenueCatGateway().getCustomerInfo(forceRefresh: true),
      throwsA(isA<PlatformException>()),
    );
    expect(methods, ['invalidateCustomerInfoCache']);
  });
}

const _emptyCustomerInfo = <String, dynamic>{
  'entitlements': {'all': <String, dynamic>{}, 'active': <String, dynamic>{}},
  'allPurchaseDates': <String, dynamic>{},
  'activeSubscriptions': <String>[],
  'allPurchasedProductIdentifiers': <String>[],
  'nonSubscriptionTransactions': <Object>[],
  'firstSeen': '2026-09-11T00:00:00Z',
  'originalAppUserId': 'test-user',
  'allExpirationDates': <String, dynamic>{},
  'requestDate': '2026-09-11T00:00:00Z',
};
