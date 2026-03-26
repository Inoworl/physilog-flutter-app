import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:physi_log/app/app.dart';
import 'package:physi_log/providers/app_providers.dart';

class AppBootstrapConfig {
  const AppBootstrapConfig({
    this.overrides = const [],
    this.initializeFirebase = true,
    this.ensureAnonymousSignIn = true,
    this.firebaseOptions,
  });

  final List<Override> overrides;
  final bool initializeFirebase;
  final bool ensureAnonymousSignIn;
  final FirebaseOptions? firebaseOptions;
}

Future<void> bootstrapApp([
  AppBootstrapConfig config = const AppBootstrapConfig(),
]) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  if (config.initializeFirebase) {
    await _initializeFirebase(config.firebaseOptions);
  }

  final container = ProviderContainer(overrides: config.overrides);
  if (config.ensureAnonymousSignIn) {
    await container.read(authServiceProvider).ensureAnonymousSignIn();
  }

  runApp(UncontrolledProviderScope(container: container, child: const App()));
}

Future<void> _initializeFirebase(FirebaseOptions? options) async {
  try {
    if (Firebase.apps.isEmpty) {
      if (options == null) {
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(options: options);
      }
    }
  } catch (e) {
    debugPrint('Firebase初期化をスキップしました: $e');
  }
}
