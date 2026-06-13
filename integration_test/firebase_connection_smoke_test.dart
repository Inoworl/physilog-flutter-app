import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:physi_log/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.isAnonymous) {
      await user.delete();
    }
    await FirebaseAuth.instance.signOut();
  });

  testWidgets('Firebaseに接続して匿名認証できる', (_) async {
    const flavor = String.fromEnvironment('FLAVOR');
    const expectedProjectId = flavor == 'prod' || flavor == 'production'
        ? 'physilog-cb6cd'
        : 'physilog-dev';

    try {
      await Firebase.initializeApp(options: AppFirebaseOptions.currentPlatform);
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') {
        rethrow;
      }
    }

    expect(Firebase.app().options.projectId, expectedProjectId);

    final auth = FirebaseAuth.instanceFor(app: Firebase.app());

    await auth.signOut();

    final credential = await auth.signInAnonymously();
    final user = credential.user;

    expect(user, isNotNull);
    expect(user!.isAnonymous, isTrue);
    expect(auth.currentUser?.uid, user.uid);
  });
}
