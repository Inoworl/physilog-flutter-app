import 'package:physi_log/features/entitlements/domain/entitlement_repository.dart';
import 'package:physi_log/models/entitlement.dart';

class NoEntitlementRepository implements EntitlementRepository {
  const NoEntitlementRepository();

  @override
  Stream<Entitlement?> watchCurrentEntitlement({required String userId}) {
    return Stream.value(null);
  }

  @override
  Future<Entitlement?> getCurrentEntitlement({required String userId}) async {
    return null;
  }
}
