import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:physi_log/app/overrides/mock_app_overrides.dart';
import 'package:physi_log/app/physi_log_root.dart';

/// Firebase に依存しない mock 構成でアプリを起動するエントリーポイント。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  runApp(PhysiLogRoot(overrides: mockAppOverrides()));
}
