enum PlanTier { free, personalFamily, team }

class PlanCapabilities {
  const PlanCapabilities({
    required this.maxAthleteCount,
    required this.maxEventCount,
    required this.canUseMeasurementSessions,
    required this.canUseGrowthSharing,
    required this.canExportCsv,
  });

  static const free = PlanCapabilities(
    maxAthleteCount: 1,
    maxEventCount: 3,
    canUseMeasurementSessions: false,
    canUseGrowthSharing: false,
    canExportCsv: false,
  );

  static const personalFamily = PlanCapabilities(
    maxAthleteCount: 5,
    maxEventCount: null,
    canUseMeasurementSessions: false,
    canUseGrowthSharing: false,
    canExportCsv: false,
  );

  static const team = PlanCapabilities(
    maxAthleteCount: null,
    maxEventCount: null,
    canUseMeasurementSessions: true,
    canUseGrowthSharing: true,
    canExportCsv: true,
  );

  static PlanCapabilities forTier(PlanTier tier) {
    return switch (tier) {
      PlanTier.free => free,
      PlanTier.personalFamily => personalFamily,
      PlanTier.team => team,
    };
  }

  /// 上限なしはnullで表す。
  final int? maxAthleteCount;
  final int? maxEventCount;
  final bool canUseMeasurementSessions;
  final bool canUseGrowthSharing;
  final bool canExportCsv;

  bool get hasUnlimitedAthletes => maxAthleteCount == null;

  bool get hasUnlimitedEvents => maxEventCount == null;

  bool canAddAthlete(int currentCount) {
    return maxAthleteCount == null || currentCount < maxAthleteCount!;
  }

  bool canAddEvent(int currentCount) {
    return maxEventCount == null || currentCount < maxEventCount!;
  }
}

class PlanAccessStatus {
  const PlanAccessStatus({
    required this.hasRevenueCatPersonalFamily,
    required this.hasRevenueCatTeam,
    required this.hasLegacyPersonalFamily,
    required this.hasLegacyTeam,
    required this.hasManualTeam,
  });

  final bool hasRevenueCatPersonalFamily;
  final bool hasRevenueCatTeam;
  final bool hasLegacyPersonalFamily;
  final bool hasLegacyTeam;
  final bool hasManualTeam;

  PlanTier get tier {
    if (hasRevenueCatTeam || hasLegacyTeam || hasManualTeam) {
      return PlanTier.team;
    }
    if (hasRevenueCatPersonalFamily || hasLegacyPersonalFamily) {
      return PlanTier.personalFamily;
    }
    return PlanTier.free;
  }

  PlanCapabilities get capabilities => PlanCapabilities.forTier(tier);
}

class PlanAccessPolicy {
  const PlanAccessPolicy();

  PlanAccessStatus evaluate({
    required bool hasRevenueCatPersonalFamily,
    required bool hasRevenueCatTeam,
    required bool hasLegacyPersonalFamily,
    required bool hasLegacyTeam,
    required bool hasManualTeam,
  }) {
    return PlanAccessStatus(
      hasRevenueCatPersonalFamily: hasRevenueCatPersonalFamily,
      hasRevenueCatTeam: hasRevenueCatTeam,
      hasLegacyPersonalFamily: hasLegacyPersonalFamily,
      hasLegacyTeam: hasLegacyTeam,
      hasManualTeam: hasManualTeam,
    );
  }
}
