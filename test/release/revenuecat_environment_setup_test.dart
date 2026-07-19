import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/domain/revenuecat_environment.dart';

void main() {
  group('RevenueCat environment setup', () {
    test('purchases_flutter is declared as an app dependency', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, contains('purchases_flutter:'));
    });

    test('Android manifest declares Google Play Billing permission', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(
        manifest,
        contains(
          '<uses-permission android:name="com.android.vending.BILLING" />',
        ),
      );
    });

    test('RevenueCatEnvironment reads public SDK keys from dart-define', () {
      final environment = File(
        'lib/features/billing/domain/revenuecat_environment.dart',
      ).readAsStringSync();

      expect(
        environment,
        contains("String.fromEnvironment('REVENUECAT_IOS_API_KEY')"),
      );
      expect(
        environment,
        contains("String.fromEnvironment('REVENUECAT_ANDROID_API_KEY')"),
      );
    });

    test('releaseではTest Store keyを拒否する', () {
      const environment = RevenueCatEnvironment(
        iosApiKey: 'test_not-a-secret',
        androidApiKey: '',
      );

      expect(
        () =>
            environment.apiKeyFor(RevenueCatPlatform.ios, isReleaseMode: true),
        throwsA(isA<RevenueCatTestStoreKeyInReleaseException>()),
      );
    });

    test('RevenueCat identityのライフサイクルをProviderで管理する', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      final appSource = File('lib/app/app.dart').readAsStringSync();

      expect(mainSource, isNot(contains('_initializeRevenueCat')));
      expect(appSource, contains('billingIdentitySyncProvider'));
    });
  });
}
