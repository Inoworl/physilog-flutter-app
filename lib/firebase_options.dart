import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class AppFirebaseOptions {
  AppFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    const flavor = String.fromEnvironment(
      'FLAVOR',
      defaultValue: 'development',
    );
    final isProduction = flavor == 'prod' || flavor == 'production';

    if (kIsWeb) {
      throw UnsupportedError(
        'AppFirebaseOptions have not been configured for web.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return isProduction ? androidProd : androidDev;
      case TargetPlatform.iOS:
        return isProduction ? iosProd : iosDev;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'AppFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions androidDev = FirebaseOptions(
    apiKey: 'AIzaSyBEAr9j1XOb6fSkLggCOCu1iq-YgtDguZo',
    appId: '1:294569277060:android:390d67129850795bb5f4d1',
    messagingSenderId: '294569277060',
    projectId: 'physilog-dev',
    storageBucket: 'physilog-dev.firebasestorage.app',
  );

  static const FirebaseOptions androidProd = FirebaseOptions(
    apiKey: 'AIzaSyAeibTX10Lln20d5qcUfqIRIDPAXgTNfF4',
    appId: '1:1052025618670:android:aff3732373dd17cfd5b3ff',
    messagingSenderId: '1052025618670',
    projectId: 'physilog-cb6cd',
    storageBucket: 'physilog-cb6cd.firebasestorage.app',
  );

  static const FirebaseOptions iosDev = FirebaseOptions(
    apiKey: 'AIzaSyCgZwSxWy3gOBwahPQWkEBetX-corH8Uwk',
    appId: '1:294569277060:ios:35416b20e608bb4fb5f4d1',
    messagingSenderId: '294569277060',
    projectId: 'physilog-dev',
    storageBucket: 'physilog-dev.firebasestorage.app',
    iosBundleId: 'com.inoworl.physilog.dev',
  );

  static const FirebaseOptions iosProd = FirebaseOptions(
    apiKey: 'AIzaSyCjD3M8JIPmiTSBenaho0YLkA7pGunjDCk',
    appId: '1:1052025618670:ios:975fa8cf3dad9773d5b3ff',
    messagingSenderId: '1052025618670',
    projectId: 'physilog-cb6cd',
    storageBucket: 'physilog-cb6cd.firebasestorage.app',
    iosBundleId: 'com.inoworl.physilog',
  );
}
