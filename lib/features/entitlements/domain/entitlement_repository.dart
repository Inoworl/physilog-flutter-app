import 'package:physi_log/models/entitlement.dart';

abstract class EntitlementRepository {
  Future<Entitlement?> getCurrentEntitlement({required String userId});
}
