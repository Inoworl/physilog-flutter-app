import 'plan_access_policy.dart';

sealed class PlanAccessState {
  const PlanAccessState();
}

final class PlanAccessLoading extends PlanAccessState {
  const PlanAccessLoading();
}

final class PlanAccessReady extends PlanAccessState {
  const PlanAccessReady(this.status);

  final PlanAccessStatus status;

  PlanTier get tier => status.tier;

  PlanCapabilities get capabilities => status.capabilities;
}

final class PlanAccessError extends PlanAccessState {
  const PlanAccessError();
}
