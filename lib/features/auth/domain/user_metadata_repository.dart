abstract class UserMetadataRepository {
  Future<void> ensureAnonymousUserCreated({required String userId});

  Future<void> markEmailLinked({required String userId});
}
