import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/firebase_options.dart';

void main() {
  test('FLAVOR selects the matching Firebase project', () {
    const flavor = String.fromEnvironment(
      'FLAVOR',
      defaultValue: 'development',
    );
    const expectedProjectId =
        flavor == 'prod' || flavor == 'production'
            ? 'physilog-cb6cd'
            : 'physilog-dev';

    expect(AppFirebaseOptions.currentPlatform.projectId, expectedProjectId);
  });

  test('Firebase options use Inoworl mobile app ids', () {
    expect(AppFirebaseOptions.androidDev.appId, contains(':android:390d671'));
    expect(AppFirebaseOptions.androidProd.appId, contains(':android:aff373'));
    expect(AppFirebaseOptions.iosDev.iosBundleId, 'com.inoworl.physilog.dev');
    expect(AppFirebaseOptions.iosProd.iosBundleId, 'com.inoworl.physilog');
  });
}
