import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/application/revenuecat_service.dart';
import 'package:physi_log/features/billing/domain/revenuecat_catalog.dart';
import 'package:physi_log/features/billing/domain/revenuecat_environment.dart';

void main() {
  group('RevenueCatService', () {
    test('APIキーが未設定ならSDKを初期化しない', () async {
      final client = _FakeRevenueCatClient();
      const environment = RevenueCatEnvironment(
        iosApiKey: '',
        androidApiKey: '',
      );
      final service = RevenueCatService(
        client: client,
        environment: environment,
        platform: RevenueCatPlatform.ios,
      );

      final configured = await service.configure(appUserId: 'user-1');

      expect(configured, isFalse);
      expect(client.configureCalls, isEmpty);
    });

    test('対象プラットフォームのAPIキーでSDKを初期化する', () async {
      final client = _FakeRevenueCatClient();
      const environment = RevenueCatEnvironment(
        iosApiKey: 'ios-key',
        androidApiKey: 'android-key',
      );
      final service = RevenueCatService(
        client: client,
        environment: environment,
        platform: RevenueCatPlatform.android,
      );

      final configured = await service.configure(appUserId: 'user-1');

      expect(configured, isTrue);
      expect(client.configureCalls, [
        const _ConfigureCall(apiKey: 'android-key', appUserId: 'user-1'),
      ]);
    });

    test('pro Entitlementの有効状態を確認する', () async {
      final client = _FakeRevenueCatClient(
        activeEntitlementIds: {RevenueCatCatalog.proEntitlementId},
      );
      final service = RevenueCatService(
        client: client,
        platform: RevenueCatPlatform.ios,
      );

      final hasLifetimePro = await service.hasLifetimePro();

      expect(hasLifetimePro, isTrue);
      expect(client.checkedEntitlementIds, [
        RevenueCatCatalog.proEntitlementId,
      ]);
    });
  });
}

class _FakeRevenueCatClient implements RevenueCatClient {
  _FakeRevenueCatClient({Set<String> activeEntitlementIds = const {}})
    : _activeEntitlementIds = activeEntitlementIds;

  final Set<String> _activeEntitlementIds;
  final configureCalls = <_ConfigureCall>[];
  final checkedEntitlementIds = <String>[];

  @override
  Future<void> configure({
    required String apiKey,
    required String? appUserId,
  }) async {
    configureCalls.add(_ConfigureCall(apiKey: apiKey, appUserId: appUserId));
  }

  @override
  Future<bool> hasActiveEntitlement(String entitlementId) async {
    checkedEntitlementIds.add(entitlementId);
    return _activeEntitlementIds.contains(entitlementId);
  }
}

class _ConfigureCall {
  const _ConfigureCall({required this.apiKey, required this.appUserId});

  final String apiKey;
  final String? appUserId;

  @override
  bool operator ==(Object other) {
    return other is _ConfigureCall &&
        other.apiKey == apiKey &&
        other.appUserId == appUserId;
  }

  @override
  int get hashCode => Object.hash(apiKey, appUserId);

  @override
  String toString() {
    return '_ConfigureCall(apiKey: $apiKey, appUserId: $appUserId)';
  }
}
