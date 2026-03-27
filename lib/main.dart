import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:physi_log/app/app.dart';
import 'package:physi_log/features/auth/application/auth_service.dart';
import 'package:physi_log/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await _initializeFirebase();

  runApp(const ProviderScope(child: App()));
}

Future<void> _initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: AppFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    // Firebase 設定がない環境でもローカル保存モードの起動は継続する。
    debugPrint('Firebase初期化をスキップしました: $e');
    return;
  }

  final authService = AuthService.create();
  await authService.ensureAnonymousSignIn();
}
