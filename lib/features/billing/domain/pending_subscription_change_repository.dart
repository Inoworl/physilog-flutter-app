class PendingSubscriptionChange {
  const PendingSubscriptionChange({
    required this.previousProductId,
    required this.targetProductId,
    required this.createdAt,
  });

  final String previousProductId;
  final String targetProductId;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) {
    return other is PendingSubscriptionChange &&
        other.previousProductId == previousProductId &&
        other.targetProductId == targetProductId &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(previousProductId, targetProductId, createdAt);
  }
}

abstract interface class PendingSubscriptionChangeRepository {
  Future<PendingSubscriptionChange?> get({required String userId});

  Future<void> save({
    required String userId,
    required PendingSubscriptionChange change,
  });

  Future<void> delete({required String userId});
}

class NoPendingSubscriptionChangeRepository
    implements PendingSubscriptionChangeRepository {
  const NoPendingSubscriptionChangeRepository();

  @override
  Future<void> delete({required String userId}) async {}

  @override
  Future<PendingSubscriptionChange?> get({required String userId}) async {
    return null;
  }

  @override
  Future<void> save({
    required String userId,
    required PendingSubscriptionChange change,
  }) async {}
}
