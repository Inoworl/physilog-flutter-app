import 'package:physi_log/app/bootstrap.dart';
import 'package:physi_log/app/overrides/mock_app_overrides.dart';

Future<void> main() async {
  await bootstrapApp(
    AppBootstrapConfig(
      overrides: mockAppOverrides(),
      initializeFirebase: false,
      ensureAnonymousSignIn: false,
    ),
  );
}
