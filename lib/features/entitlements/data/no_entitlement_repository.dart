import 'package:physi_log/features/entitlements/domain/entitlement_repository.dart';
import 'package:physi_log/models/entitlement.dart';

class NoEntitlementRepository implements EntitlementRepository {
  const NoEntitlementRepository();

  @override
  Future<Entitlement?> getCurrentEntitlement({required String userId}) async {
    return null;
  }
}
