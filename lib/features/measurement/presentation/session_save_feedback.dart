import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/features/billing/domain/recording_scope.dart';

Future<Result?> saveSessionWithFeedback<Result>(
  BuildContext context,
  Future<Result> Function() save,
) async {
  try {
    return await save();
  } on PlanAccessException catch (error) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('保存できませんでした。${error.message}'),
          action: SnackBarAction(
            label: 'プランを確認',
            onPressed: () {
              if (context.mounted) context.pushNamed('settingsPlan');
            },
          ),
        ),
      );
    return null;
  }
}
