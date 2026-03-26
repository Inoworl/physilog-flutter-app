import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
