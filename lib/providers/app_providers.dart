import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:physi_log/features/auth/application/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService.create();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges();
});

// Firebase未初期化時もローカル保存を継続できるようフォールバックする
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (user) => user?.uid ?? 'local-user',
    orElse: () => 'local-user',
  );
});
