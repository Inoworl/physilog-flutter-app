import 'package:flutter_riverpod/flutter_riverpod.dart';

// Firebase Auth UID provider (匿名ログイン後に設定)
final currentUserIdProvider = StateProvider<String?>((ref) => null);
