import 'package:hive/hive.dart';

import '../domain/pending_subscription_change_repository.dart';

class HivePendingSubscriptionChangeRepository
    implements PendingSubscriptionChangeRepository {
  static const boxName = 'pending_subscription_changes';

  Box<Map>? _box;

  Future<Box<Map>> get box async {
    _box ??= await Hive.openBox<Map>(boxName);
    return _box!;
  }

  @override
  Future<void> delete({required String userId}) async {
    final pendingChanges = await box;
    await pendingChanges.delete(userId);
  }

  @override
  Future<PendingSubscriptionChange?> get({required String userId}) async {
    final pendingChanges = await box;
    final stored = pendingChanges.get(userId);
    if (stored == null) {
      return null;
    }

    final value = Map<String, dynamic>.from(stored);
    final previousProductId = value['previousProductId'];
    final targetProductId = value['targetProductId'];
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    if (previousProductId is! String ||
        targetProductId is! String ||
        createdAt == null) {
      return null;
    }

    return PendingSubscriptionChange(
      previousProductId: previousProductId,
      targetProductId: targetProductId,
      createdAt: createdAt,
    );
  }

  @override
  Future<void> save({
    required String userId,
    required PendingSubscriptionChange change,
  }) async {
    final pendingChanges = await box;
    await pendingChanges.put(userId, {
      'previousProductId': change.previousProductId,
      'targetProductId': change.targetProductId,
      'createdAt': change.createdAt.toIso8601String(),
    });
  }
}
