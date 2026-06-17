abstract class UserMetadataRepository {
  Future<void> ensureAnonymousUserCreated({required String userId});

  Future<void> markEmailLinked({required String userId});

  Future<void> deleteUserData({required String userId});
}
