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
}
