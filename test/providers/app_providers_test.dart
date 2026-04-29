import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/providers/app_providers.dart';

void main() {
  test('currentUserIdProviderは未認証時にnullを返す', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final userId = container.read(currentUserIdProvider);
    expect(userId, isNull);
  });

  test('useFirestoreProviderは認証済みならtrueを返す', () {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('firebase-user-id'),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(useFirestoreProvider), isTrue);
  });

  test('useFirestoreProviderは未認証時にfalseを返す', () {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(useFirestoreProvider), isFalse);
  });

  test('dataStoreModeProviderはfirestore固定を返す', () {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('firebase-user-id'),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(dataStoreModeProvider), 'firestore');
  });
}
