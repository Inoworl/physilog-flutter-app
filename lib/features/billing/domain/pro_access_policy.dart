class ProAccessStatus {
  const ProAccessStatus({
    required this.isTrialActive,
    required this.hasLifetimePro,
    required this.isEarlyUser,
  });

  final bool isTrialActive;
  final bool hasLifetimePro;
  final bool isEarlyUser;

  bool get canUsePro => isTrialActive || hasLifetimePro || isEarlyUser;
}

class ProAccessPolicy {
  const ProAccessPolicy({this.trialDuration = const Duration(days: 7)});

  final Duration trialDuration;

  ProAccessStatus evaluate({
    required DateTime now,
    required DateTime? trialStartedAt,
    required bool hasLifetimePro,
    bool isEarlyUser = false,
  }) {
    final isTrialActive =
        trialStartedAt != null &&
        !now.isBefore(trialStartedAt) &&
        now.difference(trialStartedAt) < trialDuration;

    return ProAccessStatus(
      isTrialActive: isTrialActive,
      hasLifetimePro: hasLifetimePro,
      isEarlyUser: isEarlyUser,
    );
  }
}
