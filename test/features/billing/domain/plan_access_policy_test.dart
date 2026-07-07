import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/revenuecat_catalog.dart';

void main() {
  group('RevenueCatCatalog', () {
    test('RevenueCat側の識別子を固定する', () {
      expect(RevenueCatCatalog.personalFamilyEntitlementId, 'personal_family');
      expect(RevenueCatCatalog.teamEntitlementId, 'team');
      expect(
        RevenueCatCatalog.personalFamilyMonthlyProductId,
        'personal_family_monthly',
      );
      expect(
        RevenueCatCatalog.personalFamilyYearlyProductId,
        'personal_family_yearly',
      );
      expect(RevenueCatCatalog.teamMonthlyProductId, 'team_monthly');
      expect(RevenueCatCatalog.teamYearlyProductId, 'team_yearly');
      expect(RevenueCatCatalog.defaultOfferingId, 'default');
    });
  });

  group('PlanAccessPolicy', () {
    const policy = PlanAccessPolicy();

    PlanAccessStatus evaluate({
      bool hasRevenueCatPersonalFamily = false,
      bool hasRevenueCatTeam = false,
      bool hasLegacyPersonalFamily = false,
      bool hasLegacyTeam = false,
      bool hasManualTeam = false,
    }) {
      return policy.evaluate(
        hasRevenueCatPersonalFamily: hasRevenueCatPersonalFamily,
        hasRevenueCatTeam: hasRevenueCatTeam,
        hasLegacyPersonalFamily: hasLegacyPersonalFamily,
        hasLegacyTeam: hasLegacyTeam,
        hasManualTeam: hasManualTeam,
      );
    }

    test('entitlementなしはFreeプランになる', () {
      final status = evaluate();

      expect(status.tier, PlanTier.free);
    });

    test('RevenueCatの個人・家族entitlementで個人・家族プランになる', () {
      final status = evaluate(hasRevenueCatPersonalFamily: true);

      expect(status.tier, PlanTier.personalFamily);
    });

    test('RevenueCatのTeam entitlementでTeamプランになる', () {
      final status = evaluate(hasRevenueCatTeam: true);

      expect(status.tier, PlanTier.team);
    });

    test('Firestoreの据え置き個人・家族entitlementで個人・家族プランになる', () {
      final status = evaluate(hasLegacyPersonalFamily: true);

      expect(status.tier, PlanTier.personalFamily);
    });

    test('Firestoreの据え置きTeam entitlementでTeamプランになる', () {
      final status = evaluate(hasLegacyTeam: true);

      expect(status.tier, PlanTier.team);
    });

    test('Firestoreの手動付与Team entitlementでTeamプランになる', () {
      final status = evaluate(hasManualTeam: true);

      expect(status.tier, PlanTier.team);
    });

    test('個人・家族とTeamが両方有効ならTeamプランを優先する', () {
      final status = evaluate(
        hasRevenueCatPersonalFamily: true,
        hasManualTeam: true,
      );

      expect(status.tier, PlanTier.team);
    });
  });

  group('PlanCapabilities', () {
    test('Freeは選手1人・種目3つで計測会・成長共有・CSVを利用できない', () {
      const capabilities = PlanCapabilities.free;

      expect(capabilities.maxAthleteCount, 1);
      expect(capabilities.maxEventCount, 3);
      expect(capabilities.canUseMeasurementSessions, isFalse);
      expect(capabilities.canUseGrowthSharing, isFalse);
      expect(capabilities.canExportCsv, isFalse);
      expect(capabilities.canAddAthlete(0), isTrue);
      expect(capabilities.canAddAthlete(1), isFalse);
      expect(capabilities.canAddEvent(2), isTrue);
      expect(capabilities.canAddEvent(3), isFalse);
    });

    test('個人・家族は選手5人・種目無制限でTeam機能を利用できない', () {
      const capabilities = PlanCapabilities.personalFamily;

      expect(capabilities.maxAthleteCount, 5);
      expect(capabilities.hasUnlimitedEvents, isTrue);
      expect(capabilities.canUseMeasurementSessions, isFalse);
      expect(capabilities.canUseGrowthSharing, isFalse);
      expect(capabilities.canExportCsv, isFalse);
      expect(capabilities.canAddAthlete(4), isTrue);
      expect(capabilities.canAddAthlete(5), isFalse);
      expect(capabilities.canAddEvent(100), isTrue);
    });

    test('Teamは無制限で計測会・成長共有・CSVを利用できる', () {
      const capabilities = PlanCapabilities.team;

      expect(capabilities.hasUnlimitedAthletes, isTrue);
      expect(capabilities.hasUnlimitedEvents, isTrue);
      expect(capabilities.canUseMeasurementSessions, isTrue);
      expect(capabilities.canUseGrowthSharing, isTrue);
      expect(capabilities.canExportCsv, isTrue);
      expect(capabilities.canAddAthlete(100), isTrue);
      expect(capabilities.canAddEvent(100), isTrue);
    });

    test('プランからcapabilityを取得できる', () {
      expect(PlanCapabilities.forTier(PlanTier.free), PlanCapabilities.free);
      expect(
        PlanCapabilities.forTier(PlanTier.personalFamily),
        PlanCapabilities.personalFamily,
      );
      expect(PlanCapabilities.forTier(PlanTier.team), PlanCapabilities.team);
    });
  });
}
