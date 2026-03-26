import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:physi_log/firebase_options_dev.dart' as dev;
import 'package:physi_log/firebase_options_prod.dart' as prod;

class AppFirebaseOptions {
  AppFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'development');
    final isProduction = flavor == 'prod' || flavor == 'production';
    return isProduction
        ? prod.DefaultFirebaseOptions.currentPlatform
        : dev.DefaultFirebaseOptions.currentPlatform;
  }
}
