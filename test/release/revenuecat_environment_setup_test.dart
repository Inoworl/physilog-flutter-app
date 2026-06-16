import 'dart:convert';
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

    test('dart-define files expose RevenueCat public SDK key placeholders', () {
      for (final path in [
        'dart_define/dev_dart_define.json',
        'dart_define/prod_dart_define.json',
      ]) {
        final values =
            jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

        expect(values, contains('REVENUECAT_IOS_API_KEY'), reason: path);
        expect(values, contains('REVENUECAT_ANDROID_API_KEY'), reason: path);
      }
    });
  });
}
