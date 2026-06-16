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
    final now = DateTime.utc(2026, 6, 15);
    const policy = ProAccessPolicy();

    test('初回利用から7日未満はPro機能を利用できる', () {
      final status = policy.evaluate(
        now: now,
        trialStartedAt: now.subtract(const Duration(days: 6, hours: 23)),
        hasLifetimePro: false,
      );

      expect(status.isTrialActive, isTrue);
      expect(status.canUsePro, isTrue);
    });

    test('7日経過後かつ未購入ならPro機能を利用できない', () {
      final status = policy.evaluate(
        now: now,
        trialStartedAt: now.subtract(const Duration(days: 7)),
        hasLifetimePro: false,
      );

      expect(status.isTrialActive, isFalse);
      expect(status.canUsePro, isFalse);
    });

    test('買い切り購入済みまたは特別ユーザーならPro機能を利用できる', () {
      final purchased = policy.evaluate(
        now: now,
        trialStartedAt: now.subtract(const Duration(days: 30)),
        hasLifetimePro: true,
      );
      final earlyUser = policy.evaluate(
        now: now,
        trialStartedAt: null,
        hasLifetimePro: false,
        isEarlyUser: true,
      );

      expect(purchased.canUsePro, isTrue);
      expect(earlyUser.canUsePro, isTrue);
    });
  });
}
