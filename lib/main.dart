import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:physi_log/app/app.dart';
import 'package:physi_log/features/billing/application/revenuecat_service.dart';
import 'package:physi_log/features/auth/application/auth_service.dart';
import 'package:physi_log/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final userId = await _initializeFirebase();
  await _initializeRevenueCat(userId);

  runApp(const ProviderScope(child: App()));
}

Future<String?> _initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: AppFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    // Firebase 設定がない環境でもローカル保存モードの起動は継続する。
    debugPrint('Firebase初期化をスキップしました: $e');
    return null;
  }

  final authService = AuthService.create();
  return authService.ensureAnonymousSignIn();
}

Future<void> _initializeRevenueCat(String? userId) async {
  try {
    await const RevenueCatService().configure(appUserId: userId);
  } catch (e) {
    // RevenueCat未設定の開発環境でもアプリ起動は継続する。
    debugPrint('RevenueCat初期化をスキップしました: $e');
  }
}
