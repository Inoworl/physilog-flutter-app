import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/domain/revenuecat_environment.dart';

void main() {
  group('RevenueCatEnvironment', () {
    test('空文字のAPIキーは未設定として扱う', () {
      const environment = RevenueCatEnvironment(
        iosApiKey: '',
        androidApiKey: '   ',
      );

      expect(environment.apiKeyFor(RevenueCatPlatform.ios), isNull);
      expect(environment.apiKeyFor(RevenueCatPlatform.android), isNull);
    });

    test('プラットフォームごとにAPIキーを返す', () {
      const environment = RevenueCatEnvironment(
        iosApiKey: 'ios-key',
        androidApiKey: 'android-key',
      );

      expect(environment.apiKeyFor(RevenueCatPlatform.ios), 'ios-key');
      expect(environment.apiKeyFor(RevenueCatPlatform.android), 'android-key');
    });
  });
}
