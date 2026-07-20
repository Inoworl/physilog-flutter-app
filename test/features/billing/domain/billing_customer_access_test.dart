import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/domain/billing_customer_access.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_result.dart';
import 'package:physi_log/features/billing/domain/revenuecat_catalog.dart';

void main() {
  group('BillingCustomerAccess', () {
    test('active entitlement IDから個人・家族とTeamの権限を導出する', () {
      final access = BillingCustomerAccess(
        activeEntitlementIds: {
          RevenueCatCatalog.personalFamilyEntitlementId,
          RevenueCatCatalog.teamEntitlementId,
        },
      );

      expect(access.hasPersonalFamily, isTrue);
      expect(access.hasTeam, isTrue);
    });

    test('呼び出し元のSetを変更してもactive entitlementは変わらない', () {
      final entitlementIds = <String>{
        RevenueCatCatalog.personalFamilyEntitlementId,
      };
      final access = BillingCustomerAccess(
        activeEntitlementIds: entitlementIds,
      );

      entitlementIds.add(RevenueCatCatalog.teamEntitlementId);

      expect(access.hasPersonalFamily, isTrue);
      expect(access.hasTeam, isFalse);
      expect(
        () => access.activeEntitlementIds.add('another_entitlement'),
        throwsUnsupportedError,
      );
    });
  });

  group('BillingPurchaseResult', () {
    test('購入成功は更新後の顧客アクセスを保持する', () {
      final access = BillingCustomerAccess(
        activeEntitlementIds: {RevenueCatCatalog.personalFamilyEntitlementId},
      );

      final result = BillingPurchaseResult.purchased(access);

      expect(result.status, BillingPurchaseStatus.purchased);
      expect(result.customerAccess, access);
    });

    test('キャンセルと失敗をSDK例外なしで区別する', () {
      const cancelled = BillingPurchaseResult.cancelled();
      const failed = BillingPurchaseResult.failed();

      expect(cancelled.status, BillingPurchaseStatus.cancelled);
      expect(cancelled.customerAccess, isNull);
      expect(failed.status, BillingPurchaseStatus.failed);
      expect(failed.customerAccess, isNull);
    });
  });
}
