import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mock mobile build config', () {
    test('Android mock flavor does not require google-services.json', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(gradle, contains('create("mock")'));
      expect(
        gradle,
        isNot(contains('id("com.google.gms.google-services")')),
        reason:
            'The Google Services plugin fails before main_mock.dart can start '
            'when google-services.json is absent.',
      );
      expect(
        gradle,
        contains('apply(plugin = "com.google.gms.google-services")'),
      );
      expect(gradle, contains('isGoogleServicesEnabledBuild'));
    });

    test(
      'iOS project does not require GoogleService-Info.plist as a resource',
      () {
        final project = File(
          'ios/Runner.xcodeproj/project.pbxproj',
        ).readAsStringSync();

        expect(
          project,
          isNot(contains('GoogleService-Info.plist in Resources')),
          reason:
              'main_mock.dart should be runnable on iOS simulators without a '
              'checked-in Firebase plist.',
        );
        expect(
          project,
          isNot(contains('Runner/GoogleService-Info.plist')),
          reason:
              'A fixed missing plist reference prevents mock simulator builds.',
        );
      },
    );
  });
}
