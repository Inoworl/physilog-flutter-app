import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/entitlements/domain/entitlement_repository.dart';
import 'package:physi_log/models/entitlement.dart';
import 'package:physi_log/providers/app_providers.dart';

void main() {
  test('currentUserIdProviderは未認証時にlocal-userを返す', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final userId = container.read(currentUserIdProvider);
    expect(userId, 'local-user');
  });

  test('useFirestoreProviderはmodeがfirestoreかつ認証済みならtrueを返す', () {
    final container = ProviderContainer(
      overrides: [
        dataStoreModeProvider.overrideWithValue(DataStoreMode.firestore),
        currentUserIdProvider.overrideWithValue('firebase-user-id'),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(useFirestoreProvider), isTrue);
  });

  test('useFirestoreProviderはlocal-user時にfalseを返す', () {
    final container = ProviderContainer(
      overrides: [
        dataStoreModeProvider.overrideWithValue(DataStoreMode.firestore),
        currentUserIdProvider.overrideWithValue('local-user'),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(useFirestoreProvider), isFalse);
  });

  test('isPremiumEnabledProviderは個人PRO entitlementならtrueを返す', () async {
    final now = DateTime(2026, 5, 27, 10);
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('firebase-user-id'),
        entitlementRepositoryProvider.overrideWithValue(
          _FakeEntitlementRepository(
            Entitlement(
              id: 'current',
              userId: 'firebase-user-id',
              plan: EntitlementPlans.pro,
              source: EntitlementSources.manual,
              status: EntitlementStatuses.active,
              grantedAt: now,
              updatedAt: now,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(currentEntitlementProvider.future);

    expect(container.read(isPremiumEnabledProvider), isTrue);
  });

  test(
    'isPremiumEnabledProviderはRevenueCatのpro entitlementならtrueを返す',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('firebase-user-id'),
          entitlementRepositoryProvider.overrideWithValue(
            const _FakeEntitlementRepository(null),
          ),
          hasRevenueCatProProvider.overrideWith((ref) async => true),
        ],
      );
      addTearDown(container.dispose);

      await container.read(currentEntitlementProvider.future);
      await container.read(hasRevenueCatProProvider.future);

      expect(container.read(isPremiumEnabledProvider), isTrue);
      expect(container.read(isOrganizationProEnabledProvider), isFalse);
    },
  );

  test('isOrganizationProEnabledProviderは団体PRO entitlementならtrueを返す', () async {
    final now = DateTime(2026, 5, 27, 10);
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('firebase-user-id'),
        entitlementRepositoryProvider.overrideWithValue(
          _FakeEntitlementRepository(
            Entitlement(
              id: 'current',
              userId: 'firebase-user-id',
              plan: EntitlementPlans.organizationPro,
              source: EntitlementSources.manual,
              status: EntitlementStatuses.active,
              grantedAt: now,
              updatedAt: now,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(currentEntitlementProvider.future);

    expect(container.read(isPremiumEnabledProvider), isTrue);
    expect(container.read(isOrganizationProEnabledProvider), isTrue);
  });

  test('isPremiumEnabledProviderはentitlement未付与ならfalseを返す', () async {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('firebase-user-id'),
        entitlementRepositoryProvider.overrideWithValue(
          const _FakeEntitlementRepository(null),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(currentEntitlementProvider.future);

    expect(container.read(isPremiumEnabledProvider), isFalse);
  });
}

class _FakeEntitlementRepository implements EntitlementRepository {
  const _FakeEntitlementRepository(this.entitlement);

  final Entitlement? entitlement;

  @override
  Future<Entitlement?> getCurrentEntitlement({required String userId}) async {
    return entitlement;
  }
}
