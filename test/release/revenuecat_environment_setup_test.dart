import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
  });
}
