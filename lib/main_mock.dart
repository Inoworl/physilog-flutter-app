import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:physi_log/app/overrides/mock_app_overrides.dart';
import 'package:physi_log/app/physi_log_root.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';

/// Firebase に依存しない mock 構成でアプリを起動するエントリーポイント。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  const selectedPlan = String.fromEnvironment('PREVIEW_PLAN');
  final plan = selectedPlan.isEmpty
      ? null
      : PlanTier.values.byName(selectedPlan);
  runApp(PhysiLogRoot(overrides: mockAppOverrides(previewPlan: plan)));
}
