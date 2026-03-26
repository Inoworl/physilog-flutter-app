import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/app/overrides/mock_app_overrides.dart';
import 'package:physi_log/providers/app_providers.dart';
import 'package:physi_log/providers/repository_providers.dart';

void main() {
  test('mockAppOverridesはrecord/athlete/currentUserIdを差し替える', () {
    final container = ProviderContainer(overrides: mockAppOverrides());
    addTearDown(container.dispose);

    expect(container.read(currentUserIdProvider), 'mock-user');
    expect(
      container.read(recordRepositoryProvider).runtimeType.toString(),
      'InMemoryRecordRepository',
    );
    expect(
      container.read(athleteRepositoryProvider).runtimeType.toString(),
      'InMemoryAthleteRepository',
    );
  });
}
