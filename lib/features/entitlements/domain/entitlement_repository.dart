import 'package:physi_log/models/entitlement.dart';

abstract class EntitlementRepository {
  Future<Entitlement?> getCurrentEntitlement({required String userId});

  Stream<Entitlement?> watchCurrentEntitlement({required String userId});
}
