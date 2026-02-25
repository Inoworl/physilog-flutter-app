import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/providers/app_providers.dart';

void main() {
  test('currentUserIdProviderは未認証時にlocal-userを返す', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final userId = container.read(currentUserIdProvider);
    expect(userId, 'local-user');
  });
}
