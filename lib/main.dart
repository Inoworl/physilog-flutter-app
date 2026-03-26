import 'package:physi_log/app/bootstrap.dart';
import 'package:physi_log/firebase_options.dart';

Future<void> main() async {
  await bootstrapApp(
    AppBootstrapConfig(
      firebaseOptions: AppFirebaseOptions.currentPlatform,
    ),
  );
}
