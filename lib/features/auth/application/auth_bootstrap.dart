import 'package:firebase_core/firebase_core.dart';

/// Firebaseを初期化し、利用可能な場合に匿名認証を確立する。
///
/// iOSなどでネイティブ側が先にFirebaseを初期化していた場合、
/// `duplicate-app`は利用不能を意味しないため匿名認証を続行する。
Future<void> bootstrapFirebaseAuth({
  required bool Function() isFirebaseInitialized,
  required Future<void> Function() initializeFirebase,
  required Future<void> Function() ensureAnonymousSignIn,
  void Function(Object error)? onInitializationSkipped,
}) async {
  try {
    if (!isFirebaseInitialized()) {
      await initializeFirebase();
    }
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') {
      onInitializationSkipped?.call(error);
      return;
    }
  } on Object catch (error) {
    onInitializationSkipped?.call(error);
    return;
  }

  await ensureAnonymousSignIn();
}
