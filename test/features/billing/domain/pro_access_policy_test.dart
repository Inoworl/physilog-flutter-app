import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/domain/pro_access_policy.dart';
import 'package:physi_log/features/billing/domain/revenuecat_catalog.dart';

void main() {
  group('RevenueCatCatalog', () {
    test('RevenueCat側の識別子を固定する', () {
      expect(RevenueCatCatalog.proEntitlementId, 'pro');
      expect(RevenueCatCatalog.lifetimeProProductId, 'lifetime_pro');
    });
  });

  group('ProAccessPolicy', () {
    const policy = ProAccessPolicy();

    test('無料ユーザーはPro機能と団体機能を利用できない', () {
      final status = policy.evaluate(
        hasRevenueCatPro: false,
        hasEarlySupporterPro: false,
        hasOrganizationPro: false,
      );

      expect(status.canUsePro, isFalse);
      expect(status.canUseOrganizationFeatures, isFalse);
    });

    test('RevenueCatで個人PROが有効ならPro機能を利用できる', () {
      final status = policy.evaluate(
        hasRevenueCatPro: true,
        hasEarlySupporterPro: false,
        hasOrganizationPro: false,
      );

      expect(status.canUsePro, isTrue);
      expect(status.canUseOrganizationFeatures, isFalse);
    });

    test('配信初期ユーザー特典が有効なら無料でPro機能を利用できる', () {
      final status = policy.evaluate(
        hasRevenueCatPro: false,
        hasEarlySupporterPro: true,
        hasOrganizationPro: false,
      );

      expect(status.canUsePro, isTrue);
      expect(status.canUseOrganizationFeatures, isFalse);
    });

    test('団体PROが有効ならPro機能と団体機能を利用できる', () {
      final status = policy.evaluate(
        hasRevenueCatPro: false,
        hasEarlySupporterPro: false,
        hasOrganizationPro: true,
      );

      expect(status.canUsePro, isTrue);
      expect(status.canUseOrganizationFeatures, isTrue);
    });
  });
}
