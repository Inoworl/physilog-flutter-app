import '../domain/billing_customer_access.dart';
import '../domain/billing_repository.dart';
import '../domain/plan_access_policy.dart';
import '../domain/plan_access_state.dart';

class PlanAccessController {
  const PlanAccessController({
    required BillingRepository repository,
    PlanAccessPolicy policy = const PlanAccessPolicy(),
  }) : _repository = repository,
       _policy = policy;

  final BillingRepository _repository;
  final PlanAccessPolicy _policy;

  Stream<PlanAccessState> watchAccess({
    required bool hasLegacyPersonalFamily,
    required bool hasLegacyTeam,
    required bool hasManualTeam,
  }) async* {
    try {
      final initialAccess = await _repository.getCustomerAccess();
      yield _evaluate(
        initialAccess,
        hasLegacyPersonalFamily: hasLegacyPersonalFamily,
        hasLegacyTeam: hasLegacyTeam,
        hasManualTeam: hasManualTeam,
      );

      await for (final access in _repository.watchCustomerAccess()) {
        yield _evaluate(
          access,
          hasLegacyPersonalFamily: hasLegacyPersonalFamily,
          hasLegacyTeam: hasLegacyTeam,
          hasManualTeam: hasManualTeam,
        );
      }
    } on Object {
      yield const PlanAccessError();
    }
  }

  PlanAccessReady _evaluate(
    BillingCustomerAccess access, {
    required bool hasLegacyPersonalFamily,
    required bool hasLegacyTeam,
    required bool hasManualTeam,
  }) {
    return PlanAccessReady(
      _policy.evaluate(
        hasRevenueCatPersonalFamily: access.hasPersonalFamily,
        hasRevenueCatTeam: access.hasTeam,
        hasLegacyPersonalFamily: hasLegacyPersonalFamily,
        hasLegacyTeam: hasLegacyTeam,
        hasManualTeam: hasManualTeam,
      ),
    );
  }
}
