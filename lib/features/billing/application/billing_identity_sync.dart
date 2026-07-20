import '../domain/billing_repository.dart';

class BillingIdentitySync {
  BillingIdentitySync({required BillingRepository repository})
    : _repository = repository;

  final BillingRepository _repository;
  String? _currentAppUserId;
  bool _isConfigured = false;
  Future<void> _pendingSynchronization = Future.value();

  Future<void> synchronize(String? appUserId) {
    final normalizedAppUserId = appUserId?.trim();
    if (normalizedAppUserId == null || normalizedAppUserId.isEmpty) {
      return Future.value();
    }

    final synchronization = _pendingSynchronization.then(
      (_) => _synchronize(normalizedAppUserId),
    );
    _pendingSynchronization = synchronization.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return synchronization;
  }

  Future<void> _synchronize(String appUserId) async {
    if (_currentAppUserId == appUserId) {
      return;
    }

    if (!_isConfigured) {
      await _repository.configure(appUserId: appUserId);
      _isConfigured = true;
      _currentAppUserId = appUserId;
      return;
    }

    await _repository.identify(appUserId);
    _currentAppUserId = appUserId;
  }
}
